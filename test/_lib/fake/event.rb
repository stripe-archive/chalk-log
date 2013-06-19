class Critic::Fake::Event
  attr_reader :data, :time, :level

  def initialize(opts)
    @data = opts.fetch(:data)
    @time = opts.fetch(:time, Time.new(1979,4,9))
    @level = opts.fetch(:level, 1)
  end
end
