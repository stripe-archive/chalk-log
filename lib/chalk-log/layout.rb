require 'json'

# Pass metadata options as a leading hash. Everything else is
# combined into a single logical hash.
#
# log.error('Something went wrong!')
# log.ann('Booting the server on:', :host => host)
# log.ann({:important => true}, 'Booting the server on:', :host => host)
# log.error('Something went wrong', e)
# log.error({:bad => false}, 'Something went wrong', e, :info => info)
module Chalk::Log::Layout < ::Logging::Layout
  def format(event)
    data = event.data
    time = event.time
    level = event.level

    # Data provided by blocks may not be arrays yet
    data = [data] unless data.kind_of?(Array)
    while [nil, true, false].include?(data.last)
      defined?(StripeContext::AssertionUtils) && StripeContext::AssertionUtils.assertion_failed("Ignoring deprecated arguments passed to logger: #{data.inspect}")
      data.pop
    end

    info = data.pop if data.last.kind_of?(Hash)
    error = data.pop if data.last.kind_of?(Exception)
    message = data.pop if data.last.kind_of?(String)
    meta = data.pop if data.last.kind_of?(Hash)

    raise "Invalid leftover arguments: #{data.inspect}" if data.length > 0

    message = build_message(message, error, info)
    add_tags(message, time, level, meta)
  end

  private

  def action_id; defined?(LSpace) ? LSpace[:action_id] : nil; end
  def tagging_disabled; Chalk::Log::Config[:tagging_disabled]; end
  def tag_with_success; Chalk::Log::Config[:tag_with_success]; end
  def tag_without_pid; Chalk::Log::Config[:tag_without_pid]; end
  def tag_with_timestamp; Chalk::Log::Config[:tag_with_timestamp]; end
  def indent_unimportant_loglines; Chalk::Log::Config[:indent_unimportant_loglines]; end


  def build_message(message, error, info)
    message = stringify_info(info, message) if info
    message = stringify_error(error, message) if error
    message || ''
  end

  def stringify_info(info, message=nil)
    if message
      message << ': '
    else
      message = ''
    end

    # This isn't actually intended for parsing. Use a JSON output or
    # something if you want that.
    addition = info.map do |key, value|
      display(key, value)
    end
    message << addition.join(' ')
    message
  end

  # Probably let other types be logged over time, but for now we
  # should make sure that we will can serialize whatever's thrown at
  # us.
  def display(key, value)
    begin
      # Use an Array (and trim later) because Ruby's JSON generator
      # requires an array or object.
      dumped = JSON.generate([value])
    rescue => e
      e.message << " (while generating display for #{key})"
      raise
    end
    value = dumped[1...-1]

    "#{key}=#{value}"
  end

  def stringify_error(error, message=nil)
    if message
      message << ': '
    else
      message = ''
    end

    backtrace = error.backtrace || ['(no backtrace)']
    message << error.to_s << ' (' << error.class.to_s << ")\n  "
    message << Chalk::Log::Utils.format_backtrace(backtrace)

    message
  end

  def add_tags(message, time, level, meta)
    return message if tagging_disabled
    id, important, bad = interpret_meta(level, meta)

    tags = []
    tags << $$ unless tag_without_pid
    tags << id if id
    if tags.length > 0
      prefix = "[#{tags.join('|')}] "
    else
      prefix = ''
    end
    prefix = "#{timestamp_prefix(time)}#{prefix}" if tag_with_timestamp
    important = !indent_unimportant_loglines if important.nil?
    spacer = important ? '' : ' ' * 8
    if tag_with_success
      subsequent_line_success_tag = '[STRIPE-OK] '
      if success
        first_line_success_tag = subsequent_line_success_tag
      elsif success != nil
        first_line_success_tag = '[STRIPE-BAD] '
      end
    end

    out = ''
    message.split("\n").each_with_index do |line, i|
      out << prefix
      if i == 0
        out << first_line_success_tag.to_s
      else
        out << subsequent_line_success_tag.to_s
      end
      out << spacer << line << "\n"
    end
    out
  end

  def interpret_meta(level, meta)
    if meta
      id = meta[:id]
      important = meta[:important]
      bad = meta[:bad]
    end

    id ||= action_id

    level_name = Chalk::Log::LEVELS[level]
    case level_name
    when :debug, :info, :warn, :ann
      bad = false if bad.nil?
    when :error, :fatal
      bad = true if bad.nil?
    else
      raise "Unrecognized level name: #{level_name.inspect} (level: #{level.inspect})"
    end

    [id, important, bad]
  end

  def timestamp_prefix(now)
    now_fmt = now.strftime("%Y-%m-%d %H:%M:%S")
    ms_fmt = sprintf("%06d", now.usec)
    "[#{now_fmt}.#{ms_fmt}] "
  end
end
