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
end
