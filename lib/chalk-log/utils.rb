module Chalk::Log::Utils
  def self.format_backtrace(backtrace)
    if chalk_config_development? && (depth = Chalk::Log::Config[:backtrace_depth])
      non_library_line_found = false
      remaining_lines = depth
      lines = []
      backtrace.each do |line|
        break if remaining_lines == 0
        non_library_line_found ||= non_library_line?(line)
        remaining_lines -= 1 if non_library_line_found
        lines << line
      end

      if lines.length < backtrace.length
        lines << "[backtrace truncated: #{lines.length} / #{backtrace.length} lines]"
      end
    else
      lines = backtrace
    end

    "  " + lines.join("\n  ")
  end

  def self.explode_nested_hash(hash, prefix = [])
    exploded_hash = {}
    hash.each do |key,value|
      extended_prefix = prefix.clone << key
      if value.is_a?(Hash)
        exploded_hash.merge!(self.explode_nested_hash(value, extended_prefix))
      else
        exploded_hash[extended_prefix.join('_')] = value
      end
    end
    exploded_hash
  end

  def self.non_library_line?(line)
    # Relative paths are never library lines
    return true unless line.start_with?('/')

    if chalk_config_development?
      # An absolute path starting with the basedir is also not a
      # library line.
      base = Chalk::Tools::PathUtils.path
      line.start_with?(base)
    else
      false
    end
  end

  def self.chalk_config_loaded?
    defined?(Chalk::Config) && Chalk::Config.initialized?
  end

  def self.chalk_config_development?
    chalk_config_loaded? && Chalk::Config.development?
  end
end
