module Chalk::Log::Utils
  # Nicely formats a backtrace:
  #
  # ```ruby
  # format_backtrace(['line1', 'line2'])
  # #=>   line1
  #   line2
  # ```
  #
  # (Used internally when `Chalk::Log` is formatting exceptions.)
  #
  # TODO: add autotruncating of backtraces.
  def self.format_backtrace(backtrace)
    if configatron.chalk.log.compress_backtraces
      backtrace = compress_backtrace(backtrace)
    end

    "  " + backtrace.join("\n  ")
  end

  # Explodes a nested hash to just have top-level keys. This is
  # generally useful if you have something that knows how to parse
  # kv-pairs.
  #
  # ```ruby
  # explode_nested_hash(foo: {bar: 'baz', bat: 'zom'})
  # #=> {'foo_bar' => 'baz', 'foo_bat' => 'zom'}
  # ```
  def self.explode_nested_hash(hash, prefix=nil)
    exploded = {}

    hash.each do |key, value|
      new_prefix = prefix ? "#{prefix}_#{key}" : key.to_s

      if value.is_a?(Hash)
        exploded.merge!(self.explode_nested_hash(value, new_prefix))
      else
        exploded[new_prefix] = value
      end
    end

    exploded
  end

  # Compresses a backtrace
  def self.compress_backtrace(backtrace)
    compressed = []
    gemdir = Gem.dir

    hit_application = false
    leading_lines = 0
    gemlines = 0
    backtrace.each do |line|
      if line.start_with?(gemdir)
        # If we're in a gem, always increment the counter. Record the
        # first three lines if we haven't seen any application lines
        # yet.
        if !hit_application && leading_lines < 3
          compressed << line
          leading_lines += 1
        else
          gemlines += 1
        end
      elsif gemlines > 0
        # If we were in a gem and now are not, record the number of
        # lines skipped.
        compressed << "<#{gemlines} #{gemlines == 1 ? 'line' : 'lines'} omitted>"
        compressed << line
        hit_application = true
        gemlines = 0
      else
        # If we're in the application, always record the line.
        compressed << line
        hit_application = true
      end
    end

    compressed
  end
end
