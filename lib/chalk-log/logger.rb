# Thin wrapper over Logging::Logger. This is the per-class object
# instantiated by the `log` method.
class Chalk::Log::Logger
  attr_reader :backend

  # Initialization of the logger backend. It does the actual creation
  # of the various logger methods. Will be called automatically upon
  # your first `log` method call.
  def self.init
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
    @backend = ::Logging::Logger.new(name)
    if level = configatron.chalk.log.default_level
      @backend.level = level
    end
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
    existing_context = LSpace[:'chalk.log.contextual_info'] || {}
    LSpace.with(
      :'chalk.log.contextual_info' => contextual_info.merge(existing_context),
      &blk
    )
  end
end
