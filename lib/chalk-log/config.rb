module Chalk::Log::Config
  @config = {
    :backtrace_depth => 7,
    :tag_with_timestamp => STDOUT.tty?,
    :default_level => 'INFO'
  }

  def self.[](opt)
    @config[opt]
  end

  def self.[]=(opt, value)
    @config[opt] = value
  end

  def self.update(config)
    config = config.dup

    [
      :backtrace_depth,
      :indent_unimportant_loglines,
      :default_outputters,
      :default_level,
      :tag_with_success,
      :tag_without_pid,
      :tag_with_timestamp,
      :tagging_disabled,
      :our_code_regex
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
