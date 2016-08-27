require 'json'
require 'set'
require 'time'

# The layout backend for the Logging::Logger.
#
# Accepts a message and/or an exception and/or an info
# hash (if multiple are passed, they must be provided in that
# order)
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
          error!('[Chalk::Log fault: Could not format message] ', e)
        end
      rescue StandardError => e
        # Double fault!
        "[Chalk::Log fault: Double fault while formatting message. This means we couldn't even report the error we got while formatting.] #{e.message}\n"
      end
    rescue StandardError => e
      # Triple fault!
      "[Chalk::Log fault: Triple fault while formatting message. This means we couldn't even report the error we got while reporting the original error.]\n"
    end
  end

  # Formats a hash for logging. This is provided for (rare) use outside of log
  # methods; you can pass a hash directly to log methods and this formatting
  # will automatically be applied.
  #
  # @param hash [Hash] The hash to be formatted
  def format_hash(hash)
    hash.map {|k, v| display(k, v)}.join(' ')
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

    if data.length > 0
      raise Chalk::Log::InvalidArguments.new("Invalid leftover arguments: #{data.inspect}")
    end

    pid = Process.pid

    pretty_print(
      time: timestamp_prefix(time),
      level: Chalk::Log::LEVELS[level],
      span: span.to_s,
      message: message,
      error: error,
      info: (info && (contextual_info || {}).merge(info)) || contextual_info,
      pid: pid
      )
  end

  def pretty_print(spec)
    message = build_message(spec[:message], spec[:info], spec[:error])
    message = tag(message, spec[:time], spec[:pid], spec[:span])
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

    if Chalk::Log.message_prefix
      message ||= ''
      message.prepend(Chalk::Log.message_prefix)
    end

    if info
      message << ' ' if message
      message ||= ''
      message << format_hash(info)
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
    if configatron.chalk.log.display_backtraces
      message << "\n"
      message << Chalk::Log::Utils.format_backtrace(backtrace)
      message << "\n"
    end
    message
  end

  def json(value)
    # Use an Array (and trim later) because Ruby's JSON generator
    # requires an array or object.
    wrapped = [value]

    # We may alias the raw JSON generation method. We don't care about
    # emiting raw HTML tags heres, so no need to use the safe
    # generation method.
    if JSON.respond_to?(:unsafe_generate)
      dumped = JSON.unsafe_generate(wrapped)
    else
      dumped = JSON.generate(wrapped)
    end

    res = dumped[1...-1] # strip off the brackets we added while array-ifying

    # Bug 6566 in ruby 2.0 (but not 2.1) allows generate() to return an invalid
    # string when given invalid unicode input. Manually check for it.
    unless res.valid_encoding?
      raise ArgumentError.new("invalid byte sequence in UTF-8")
    end

    res
  end

  def contextual_info
    LSpace[:'chalk.log.contextual_info']
  end

  def span
    LSpace[:span] || LSpace[:action_id]
  end

  def tag(message, time, pid, span)
    return message unless configatron.chalk.log.tagging

    metadata = []
    metadata << pid if configatron.chalk.log.pid
    metadata << span if span.length > 0
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
