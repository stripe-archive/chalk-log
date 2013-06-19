module Chalk::Log::Utils
  def self.format_backtrace(backtrace)
    if depth = Chalk::Log::Config[:backtrace_depth]
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

    lines.join("\n  ")
  end

  def self.non_library_line?(line)
    # TODO: we can probably actually auto-detect this.
    if regex = Chalk::Log::Config[:our_code_regex]
      line =~ regex
    else
      true
    end
  end
end
