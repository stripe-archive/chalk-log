require_relative '../_lib'
require_relative '../../../rubocop/clevel_constant.rb'
require_relative './helpers.rb'
require 'rubocop'


module Critic::Unit
  class Critic::Unit::Test::CLevelConstantTest < Critic::Unit::Test
    include StripeRuboCop::Helpers::MinitestHelper

    def cop_classes
      [PrisonGuard::CLevelConstant]
    end

    def self.bad_log
      "log.info('bad log using string literal', clevel: 'invalid')"
    end

    def self.good_log
      "log.warn('good log using constant', clevel: Chalk::Log::CLevels::Sheddable)"
    end

    def self.block_with_contents(contents)
      "things.map do |x|\
      #{contents}\
      end"
    end

    good_cop('ignores empty strings', '')
    good_cop('ignores methods on non-log implicit parameters', 'notalog.info')
    good_cop('ignores methods on non-log implicit parameters', 'notalog.info("not a log line")')

    good_cop('ignores logs without a hash provided', 'log.info("no hash")')
    good_cop('ignores blocks', 'log.info("no hash")')

    good_cop('allows an info with constant', good_log)
    good_cop('allows an info with constant in multikey hash', 'log.warn("using constant", merchant: "foo", clevel: Chalk::Log::CLevels::Sheddable)')


    bad_cop('rejects an info with string literal', bad_log)
    bad_cop('rejects an info with an invalid clevel', 'log.info("something", clevel: Chalk::Log::CLevels::Sleddable)')

  end
end
