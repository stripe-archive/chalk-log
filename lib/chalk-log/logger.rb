# Thin wrapper over Logging::Logger. This is the per-class object
# instantiated by the `log` method.
class Chalk::Log::Logger
  attr_reader :backend

  ROOT_LOGGER_NAME = "CHALK_LOG_ROOT".freeze
  private_constant :ROOT_LOGGER_NAME

  # Initialization of the logger backend. It does the actual creation
  # of the various logger methods. Will be called automatically upon
  # your first `log` method call.
  def self.init
    return if @initialized
    @initialized = true

    Chalk::Log::LEVELS.each do |level|
      define_method(level) do |*data, &blk|
        return if logging_disabled?
        @backend.send(level, data, &blk)
      end
    end
  end

  # The level this logger is set to.
  def level
    @backend.level
  end

  # Set the maximum log level.
  #
  # @param level [Fixnum|String|Symbol] A valid Logging::Logger level, e.g. :debug, 0, 'DEBUG', etc.
  def level=(level)
    @backend.level = level
  end

  # Create a new logger, and auto-initialize everything.
  def initialize(name)
    # It's generally a bad pattern to auto-init, but we want
    # Chalk::Log to be usable anytime during the boot process, which
    # requires being a little bit less explicit than we usually like.
    Chalk::Log.init

    # The Logging library parses the logger name to determine the correct parent
    name = Chalk::Log._root_backend.name + ::Logging::Repository::PATH_DELIMITER + (name || 'ANONYMOUS')
    @backend = ::Logging::Logger.new(name)
  end

  # Check whether logging has been globally turned off, either through
  # configatron or LSpace.
  def logging_disabled?
    configatron.chalk.log.disabled || LSpace[:'chalk.log.disabled']
  end

  def with_contextual_info(contextual_info={}, &blk)
    unless blk
      raise ArgumentError.new("Must pass a block to #{__method__}")
    end
    unless contextual_info.is_a?(Hash)
      raise TypeError.new(
        "contextual_info must be a Hash, but got #{contextual_info.class}"
      )
    end
    existing_context = LSpace[:'chalk.log.contextual_info'] || {}
    LSpace.with(
      :'chalk.log.contextual_info' => existing_context.merge(contextual_info),
      &blk
    )
  end
end
