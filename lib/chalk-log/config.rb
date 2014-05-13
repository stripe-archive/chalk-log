# TODO: this module should go away, to be replaced by configatron
module Chalk::Log::Config
  @config = {
    :tag_with_timestamp => STDOUT.tty?,
    :default_level => 'INFO',
    :output_format => 'pp'
  }

  def self.[](opt)
    @config[opt]
  end

  def self.[]=(opt, value)
    @config[opt] = value
  end

  def self.update(config)
    # Make sure we've init'd
    Chalk::Log.init

    config = config.dup

    [:our_code_regex, :backtrace_depth].each do |opt|
      if config.include?(opt) || config.include?(opt.to_s)
        raise "Deprecated config key #{opt.inspect} provided. Please remove it."
      end
    end

    [
      :indent_unimportant_loglines,
      :default_outputters,
      :default_level,
      :output_format,
      :tag_with_success,
      :tag_without_pid,
      :tag_with_timestamp,
      :tagging_disabled,
    ].each do |opt|
      if config.include?(opt)
        @config[opt] = config.delete(opt)
      elsif config.include?(opt.to_s)
        @config[opt] = config.delete(opt.to_s)
      end
    end
    if config.length > 0
      raise "Unrecognized configuration keys: #{config.keys.inspect}"
    end
  end
end
