# this code from stripe-rubocop/lib/stripe-rubocop/helpers/minitest_helper.rb
# necessary to write repo-specific rubocop tests
require 'rubocop'
require 'minitest/autorun'
require 'minitest/spec'

module StripeRuboCop
  module Helpers
    module MinitestHelper
      module ClassMethods
        def good_cop(name, code)
          it "accepts #{name}" do
            off = investigate_string(code)
            assert(off.empty?, "Expected no offenses, got: #{off.inspect}")
          end
        end

        def bad_cop(name, code)
          it "rejects #{name}" do
            assert(!investigate_string(code).empty?, "expected offenses on: #{code}")
          end
        end

        def corrects(name, from, to)
          it "corrects #{name}" do
            assert_equal(to, correct_string(from))
          end
        end
      end

      def self.included(other)
        other.extend(ClassMethods)
      end

      def cop_classes
        raise NotImplementedError
      end

      def source_path
        nil
      end

      def create_cops
        cfg = RuboCop::Config.new
        cop_classes.map {|kls| kls.new(cfg, debug: true, auto_correct: true)}
      end

      def commissioner(cops)
        RuboCop::Cop::Commissioner.new(cops, [], raise_error: true)
      end

      def investigate_string(str)
        src = RuboCop::ProcessedSource.new(str, RUBY_VERSION.to_f, source_path)
        commissioner(create_cops).investigate(src)
      end

      def correct_string(str)
        cops = create_cops

        src = RuboCop::ProcessedSource.new(str, RUBY_VERSION.to_f, source_path)
        corrector = RuboCop::Cop::Corrector.new(src.buffer)

        # Populates corrections
        commissioner(cops).investigate(src)

        cops.each do |cop|
          corrector.corrections.concat(cop.corrections)
        end

        corrector.rewrite
      end
    end
  end
end
