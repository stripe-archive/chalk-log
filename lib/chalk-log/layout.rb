require 'json'
require 'set'
require 'time'

RESERVED_KEYS = ['message', 'time', 'level', 'meta', 'id', 'pid', 'error', 'backtrace', 'error_class'].to_set

# Pass metadata options as a leading hash. Everything else is
# combined into a single logical hash.
#
# log.error('Something went wrong!')
# log.info('Booting the server on:', :host => host)
# log.error('Something went wrong', e)
# log.error({:id => 'id'}, 'Something went wrong', e, :info => info)
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

    id = meta[:id] if meta
    id ||= action_id

    pid = Process.pid

    event_description = {
      :time => timestamp_prefix(time),
      :pid => pid,
      :level => Chalk::Log::LEVELS[level],
      :id => id,
      :message => message,
      :meta => meta,
      :error => error,
      :info => info
    }.reject {|k,v| v.nil?}

    case output_format
    when 'json'
      json_print(event_description)
    when 'kv'
      kv_print(event_description)
    when 'pp'
      pretty_print(event_description)
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
  def tag_without_pid; Chalk::Log::Config[:tag_without_pid]; end
  def tag_with_timestamp; Chalk::Log::Config[:tag_with_timestamp]; end


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

  def kv_print(event_description)
    user_attributes = event_description.delete(:info) || {}
    error = event_description.delete(:error)
    time = event_description.delete(:time)

    components = []
    components << "[#{time}]" if tag_with_timestamp
    event_description.each {|key, value| components << display(key, value)}
    user_attributes.each {|key, value| components << display(key, value, true)}

    if error
      components << display(:error, error.to_s)
      components << display(:error_class, error.class.to_s)
      components << "backtrace=\n  #{Chalk::Log::Utils.format_backtrace(error.backtrace)}" if error.backtrace
    end

    components.join(' ') + "\n"
  end

  def json_print(event_description)
    JSON.generate(event_description) + "\n"
  end

  def pretty_print(event_description)
    event_description[:message] = build_message(event_description[:message], event_description[:error], event_description[:info])
    append_newline(event_description[:message])
    return event_description[:message] if tagging_disabled

    tags = []
    tags << event_description[:pid] unless tag_without_pid
    tags << event_description[:id] if event_description[:id]
    if tags.length > 0
      prefix = "[#{tags.join('|')}] "
    else
      prefix = ''
    end
    prefix = "[#{event_description[:time]}] #{prefix}" if tag_with_timestamp

    out = ''
    event_description[:message].split("\n").each_with_index do |line, i|
      out << prefix << line << "\n"
    end
    out
  end

  def timestamp_prefix(now)
    now_fmt = now.strftime("%Y-%m-%d %H:%M:%S")
    ms_fmt = sprintf("%06d", now.usec)
    "#{now_fmt}.#{ms_fmt}"
  end
end
