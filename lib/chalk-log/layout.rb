require 'json'
require 'set'
require 'time'

RESERVED_KEYS = ['message', 'time', 'level', 'meta', 'id', 'important', 'bad', 'pid', 'error', 'backtrace', 'error_class'].to_set

# Pass metadata options as a leading hash. Everything else is
# combined into a single logical hash.
#
# log.error('Something went wrong!')
# log.info('Booting the server on:', :host => host)
# log.info({:important => true}, 'Booting the server on:', :host => host)
# log.error('Something went wrong', e)
# log.error({:bad => false}, 'Something went wrong', e, :info => info)
class Chalk::Log::Layout < ::Logging::Layout
  def format(event)
    data = event.data
    time = event.time
    level = event.level

    # Data provided by blocks may not be arrays yet
    data = [data] unless data.kind_of?(Array)
    while data.length > 0 && [nil, true, false].include?(data.last)
      maybe_assert(false, "Ignoring deprecated arguments passed to logger: #{data.inspect}") unless data.last.nil?
      data.pop
    end

    info = data.pop if data.last.kind_of?(Hash)
    error = data.pop if exception?(data.last)
    message = data.pop if data.last.kind_of?(String)
    meta = data.pop if data.last.kind_of?(Hash)

    raise "Invalid leftover arguments: #{data.inspect}" if data.length > 0

    id, important, bad = interpret_meta(level, meta)
    pid = Process.pid

    log_hash = {
      :time => timestamp_prefix(time),
      :pid => pid,
      :level => Chalk::Log::LEVELS[level],
      :id => id,
      :message => message,
      :meta => meta,
      :important => important,
      :bad => bad,
      :error => error,
      :info => info
    }.reject {|k,v| v.nil?}

    case output_format
    when 'json'
      json_print(log_hash)
    when 'kv'
      kv_print(log_hash)
    when 'pp'
      pretty_print(log_hash)
    else
      raise ArgumentError, "Chalk::Log::Config[:output_format] was not set to a valid setting of 'json', 'kv', or 'pp'."
    end
  end

  private

  def maybe_assert(*args)
    # We don't require Chalk::Tools in order to avoid a cyclic
    # dependency.
    Chalk::Tools::AssertionUtils.assert(*args) if defined?(Chalk::Tools)
  end

  def exception?(object)
    if object.kind_of?(Exception)
      true
    elsif defined?(Mocha::Mock) && object.kind_of?(Mocha::Mock)
      # TODO: better answer than this?
      maybe_assert(Chalk::Tools::TestingUtils.testing?, "Passed a mock even though we're not in the tests", true) if defined?(Chalk::Tools)
      true
    else
      false
    end
  end

  def action_id; defined?(LSpace) ? LSpace[:action_id] : nil; end
  def tagging_disabled; Chalk::Log::Config[:tagging_disabled]; end
  def output_format; Chalk::Log::Config[:output_format]; end
  def tag_with_success; Chalk::Log::Config[:tag_with_success]; end
  def tag_without_pid; Chalk::Log::Config[:tag_without_pid]; end
  def tag_with_timestamp; Chalk::Log::Config[:tag_with_timestamp]; end
  def indent_unimportant_loglines; Chalk::Log::Config[:indent_unimportant_loglines]; end


  def build_message(message, error, info)
    message = stringify_info(info, message) if info
    message = stringify_error(error, message) if error
    message || ''
  end

  def append_newline(message)
    message << "\n"
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
  def display(key, value, escape_keys=false)
    key = display_key(key, escape_keys)
    value = display_value(value)

    "#{key}=#{value}"
  end

  def display_key(key, escape_keys)
    key = key.to_s
    if escape_keys && (key.start_with?('_') || RESERVED_KEYS.include?(key))
      "_#{key}"
    else
      key
    end
  end

  def display_value(value)
    begin
      # Use an Array (and trim later) because Ruby's JSON generator
      # requires an array or object.
      dumped = JSON.generate([value])
    rescue => e
      e.message << " (while generating display for #{key})"
      raise
    end

    value = dumped[1...-1] # strip off surrounding brackets
    value = value[1...-1] if value =~ /\A"[A-Z]\w*"\z/ # non-numeric simple strings that start with a capital don't need quotes

    value
  end

  def multilined_display(key, value, escape_keys=false)
    # substitute escaped by JSON new lines with actual new lines
    key = display_key(key, escape_keys)
    value = display_value(value)

    value = "\n  " + value.gsub(/([^\\]\\{2}*)\\n/, "\\1\n  ")

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

  def kv_print(log_hash)
    user_attributes = log_hash.delete(:info) || {}
    error = log_hash.delete(:error)

    components = log_hash.map {|key, value| display(key, value)} +
      user_attributes.map {|key, value| display(key, value, true)}

    if error
      components << display(:error, error.to_s)
      components << display(:error_class, error.class.to_s)
      components << "backtrace=\n  #{Chalk::Log::Utils.format_backtrace(error.backtrace)}" if error.backtrace
    end

    components.join(' ') + "\n"
  end

  def json_print(log_hash)
    JSON.generate(log_hash) + "\n"
  end

  def pretty_print(log_hash)
    log_hash[:message] = build_message(log_hash[:message], log_hash[:error], log_hash[:info])
    append_newline(log_hash[:message])
    return log_hash[:message] if tagging_disabled

    tags = []
    tags << log_hash[:pid] unless tag_without_pid
    tags << log_hash[:id] if log_hash[:id]
    if tags.length > 0
      prefix = "[#{tags.join('|')}] "
    else
      prefix = ''
    end
    prefix = "[#{log_hash[:time]}] #{prefix}" if tag_with_timestamp
    log_hash[:important] = !indent_unimportant_loglines if log_hash[:important].nil?
    spacer = log_hash[:important] ? '' : ' ' * 8
    if tag_with_success
      if log_hash[:bad] == false
        first_line_success_tag = '[CHALK-OK] '
        subsequent_line_success_tag = '[CHALK-OK] '
      elsif log_hash[:bad]
        first_line_success_tag = '[CHALK-BAD] '
        # Keep this as OK because we really only need one bad line
        subsequent_line_success_tag = '[CHALK-OK] '
      end
    end

    out = ''
    log_hash[:message].split("\n").each_with_index do |line, i|
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
    when :debug, :info, :warn
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
    "#{now_fmt}.#{ms_fmt}"
  end
end
