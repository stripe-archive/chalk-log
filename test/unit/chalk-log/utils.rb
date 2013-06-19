require_relative '../_lib'
require 'chalk-log'

class Critic::Unit::Utils < Critic::Unit::Test
  describe '.explode_nested_hash' do
    it 'explodes nested keys' do
      hash = {foo: {bar: {baz: 'zom'}, zero: 'hello'}, hi: 'there'}
      exploded = Chalk::Log::Utils.explode_nested_hash(hash)
      assert_equal({"foo_bar_baz"=>"zom", "foo_zero"=>"hello", "hi"=>"there"},
        exploded)
    end
  end
end
