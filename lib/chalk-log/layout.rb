require 'json'
require 'set'
require 'time'

# Pass metadata options as a leading hash. Everything else is
# combined into a single logical hash.
#
# log.error('Something went wrong!')
# log.info('Booting the server on:', host: host)
# log.error('Something went wrong', e)
class Chalk::Log::Layout < ::Logging::Layout
  # Formats an event, and makes a heroic effort to tell you if
  # something went wrong. (Logging will otherwise silently swallow any
  # exceptions that get thrown.)
  #
  # @param event provided by the Logging::Logger
  def format(event)
    begin
      begin
        begin
          do_format(event)
        rescue StandardError => e
          # Single fault!
          stringify_error('[Could not format message] ', e)
        end
      rescue StandardError => e
        # Double fault!
        "[Double fault while formatting message. This means we couldn't even report the error we got while formatting.] #{e.message}"
      end
    rescue StandardError => e
      # Triple fault!
      "[Triple fault while formatting message. This means we couldn't even report the error we got while reporting the original error.]"
    end
  end

  private

  def do_format(event)
    data = event.data
    time = event.time
    level = event.level

    # Data provided by blocks may not be arrays yet
    data = [data] unless data.kind_of?(Array)
    info = data.pop if data.last.kind_of?(Hash)
    error = data.pop if data.last.kind_of?(Exception)
    message = data.pop if data.last.kind_of?(String)

    raise "Invalid leftover arguments: #{data.inspect}" if data.length > 0

    id = action_id
    pid = Process.pid

    pretty_print(
      time: timestamp_prefix(time),
      level: Chalk::Log::LEVELS[level],
      action_id: id,
      message: message,
      error: error,
      info: info,
      pid: pid
      )
  end

  def pretty_print(spec)
    message = build_message(spec[:message], spec[:info], spec[:error])
    message = tag(message, spec[:time], spec[:pid], spec[:action_id])
    message
  end

  def build_message(message, info, error)
    # Make sure we're not mutating the message that was passed in
    if message
      message = message.dup
    end

    if message && (info || error)
      message << ':'
    end

    if info
      message << ' ' if message
      message ||= ''
      info!(message, info)
    end

    if error
      message << ' ' if message
      message ||= ''
      error!(message, error)
    end

    message ||= ''
    message << "\n"
    message
  end

  # Displaying info hash

  def info!(message, info)
    addition = info.map do |key, value|
      display(key, value)
    end

    message << addition.join(' ')
  end

  def display(key, value)
    begin
      value = json(value)
    rescue StandardError
      value = "#{value.inspect} [JSON-FAILED]"
    end

    # Non-numeric simple strings don't need quotes.
    if value =~ /\A"\w*[A-Za-z]\w*"\z/ &&
        !['"true"', '"false"', '"null"'].include?(value)
      value = value[1...-1]
    end

    "#{key}=#{value}"
  end

  # Displaying backtraces

  def error!(message, error)
    backtrace = error.backtrace || ['[no backtrace]']
    message << display(:error_class, error.class.to_s) << " "
    message << display(:error, error.to_s)
    message << "\n"
    message << Chalk::Log::Utils.format_backtrace(backtrace)
    message
  end

  def json(value)
    # Use an Array (and trim later) because Ruby's JSON generator
    # requires an array or object.
    wrapped = [value]

    # Chalk::Tools::JSONUtils aliases the raw JSON generation
    # method. We don't care about emiting raw HTML tags heres, so no
    # need to use the safe generation method.
    if JSON.respond_to?(:unsafe_generate)
      dumped = JSON.unsafe_generate(wrapped)
    else
      dumped = JSON.generate(wrapped)
    end

    dumped[1...-1] # strip off the brackets we added while array-ifying
  end

  def action_id
    LSpace[:action_id]
  end

  def tag(message, time, pid, action_id)
    return message unless configatron.chalk.log.tagging

    metadata = [pid, action_id].compact
    prefix = "[#{metadata.join('|')}] " if metadata.length > 0

    if configatron.chalk.log.timestamp
      prefix = "[#{time}] #{prefix}"
    end

    out = ''
    message.split("\n").each do |line|
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
