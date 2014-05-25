class Chalk::Log::Logger
  attr_reader :backend

  def self.init
    Chalk::Log::LEVELS.each do |level|
      define_method(level) do |*data, &blk|
        return if logging_disabled?
        @backend.send(level, data, &blk)
      end
    end
  end

  def level
    @backend.level
  end

  def level=(level)
    @backend.level = level
  end

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

  private

  def logging_disabled?
    configatron.chalk.log.disabled || LSpace[:'chalk.log.disabled']
  end
end
