module Chalk::Log::Utils
  # TODO: maybe add some support for autotruncating? Would need
  # some way of finding library line
  def self.format_backtrace(backtrace)
    "  " + backtrace.join("\n  ")
  end

  def self.explode_nested_hash(hash, prefix = [])
    exploded_hash = {}
    hash.each do |key,value|
      extended_prefix = prefix.clone + [key]
      if value.is_a?(Hash)
        exploded_hash.merge!(self.explode_nested_hash(value, extended_prefix))
      else
        exploded_hash[extended_prefix.join('_')] = value
      end
    end
    exploded_hash
  end
end
