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

  def self.delegate(*methods)
    methods.each do |name|
      define_method(name) do |*args, &blk|
        @backend.send(name, *args, &blk)
      end
    end
  end
  delegate(:level, :level=)

  def initialize(name)
    # Need to make sure we're inited before creating a logger.
    Chalk::Log.init
    @backend = ::Logging::Logger.new(name)
    if level = Chalk::Log::Config[:default_level]
      @backend.level = level
    end
  end

  private

  def logging_disabled?
    ENV['STRIPE_CONTEXT_LOGGING_DISABLED'] == 'yes' ||
      (defined?(LSpace) && LSpace[:logging_disabled])
  end
end
