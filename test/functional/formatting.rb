require File.expand_path('../_lib', __FILE__)

require 'chalk-log'

module Critic::Functional
  class LogTest < Test
    before do
      Chalk::Log.init
      Process.stubs(:pid).returns(9973)
    end

    class MyClass
      include Chalk::Log
    end

    describe 'when called without arguments' do
      it 'does not loop infinitely' do
        MyClass.log.info
      end
    end

    describe 'generates a pretty_print' do
      before do
        Chalk::Log::Config.update(:tag_with_timestamp => false)
        Chalk::Log::Config.update(:output_format => 'pp')
      end

      class PrettyPrintLogger
        include Chalk::Log
      end
      layout = PrettyPrintLogger::Layout.new

      it 'log entry from info' do
        event = stub(:data => [{:id => "action"}, "A Message", {:key1 => "ValueOne", :key2 => ["An", "Array"]}], :time => Time.new(1979,4,9), :level => 1)
        assert_equal('[9973|action] A Message: key1=ValueOne key2=["An","Array"]' + "\n",
          layout.format(event)
        )
      end

      it 'log entry from info without a message' do
        event = stub(:data => [{:id => "action"}, {:key1 => "ValueOne", :key2 => ["An", "Array"]}], :time => Time.new(1979,4,9), :level => 1)
        assert_equal('[9973|action] key1=ValueOne key2=["An","Array"]' + "\n",
          layout.format(event)
        )
      end

      it 'log entry from info with exploded hash' do
        exploded_hash = Chalk::Log::Utils.explode_nested_hash({:key1 => "ValueOne", :key2 => {:a => "A", :b => "Hash"}})
        event = stub(:data => [{:id => "action"}, "A Message", exploded_hash], :time => Time.new(1979,4,9), :level => 1)
        assert_equal('[9973|action] A Message: key1=ValueOne key2_a=A key2_b=Hash' + "\n",
          layout.format(event)
        )
      end

      it 'log entry from error without a backtrace' do
        event = stub(:data => [{:id => "action"}, "Another Message", StandardError.new], :time => Time.new(1979,4,9), :level => 3)
        layout.stubs(:output_format => 'pp')
        assert_equal('[9973|action] Another Message: error_class=StandardError error=StandardError' +
          "\n" + '[9973|action]   (no backtrace)' + "\n",
          layout.format(event)
        )
      end

      it 'log entry from error without a backtrace and a info hash' do
        event = stub(:data => [{:id => "action"}, "Another Message", StandardError.new, {:key1 => "ValueOne", :key2 => ["An", "Array"]}], :time => Time.new(1979,4,9), :level => 3)
        layout.stubs(:output_format => 'pp')
        assert_equal('[9973|action] Another Message: key1=ValueOne key2=["An","Array"] error_class=StandardError error=StandardError' +
          "\n" + '[9973|action]   (no backtrace)' + "\n",
          layout.format(event)
        )
      end

      it 'log entry from error with a backtrace' do
        error = StandardError.new
        backtrace = ["a fake", "backtrace"]
        error.set_backtrace(backtrace)
        event = stub(:data => [{:id => "action"}, "Yet Another Message", error], :time => Time.new(1979,4,9), :level => 3)
        layout.stubs(:output_format => 'pp')
        assert_equal('[9973|action] Yet Another Message: error_class=StandardError error=StandardError' +
          "\n" + '[9973|action]   a fake' +
          "\n" + '[9973|action]   backtrace' + "\n",
          layout.format(event)
        )
      end

      it 'handles bad unicode' do
        event = stub(:data => [{:id => "action"}, {:key1 => "ValueOne", :key2 => "\xC3"}], :time => Time.new(1979,4,9), :level => 1)
        layout.stubs(:output_format => 'pp')
        assert_equal("[9973|action] key1=ValueOne key2=\"\\xC3\"\n", layout.format(event))
      end
    end

    describe 'generates a json' do
      before do
        Chalk::Log::Config.update(:output_format => 'json')
      end

      class JSONLogger
        include Chalk::Log
      end
      layout = JSONLogger::Layout.new

      it 'log entry from info' do
        event = stub(:data => [{:id => "action"}, "A Message", {:key1 => "ValueOne", :key2 => ["An", "Array"]}], :time => Time.new(1979,4,9), :level => 1)
        assert_equal("{\"time\":\"1979-04-09 00:00:00.000000\",\"level\":\"info\",\"action_id\":\"action\",\"message\":\"A Message\",\"meta\":{\"id\":\"action\"},\"info\":{\"key1\":\"ValueOne\",\"key2\":[\"An\",\"Array\"]},\"pid\":9973}
",
          layout.format(event)
        )
      end

      it 'log entry from error without a backtrace' do
        event = stub(:data => [{:id => "action"}, "Another Message", StandardError.new], :time => Time.new(1979,4,9), :level => 3)
        assert_equal("{\"time\":\"1979-04-09 00:00:00.000000\",\"level\":\"error\",\"action_id\":\"action\",\"message\":\"Another Message\",\"meta\":{\"id\":\"action\"},\"error\":\"StandardError\",\"pid\":9973}
",
          layout.format(event)
        )
      end

      it 'log entry from error without a backtrace and a info hash' do
        event = stub(:data => [{:id => "action"}, "Another Message", StandardError.new, {:key1 => "ValueOne", :key2 => ["An", "Array"]}], :time => Time.new(1979,4,9), :level => 3)
        assert_equal("{\"time\":\"1979-04-09 00:00:00.000000\",\"level\":\"error\",\"action_id\":\"action\",\"message\":\"Another Message\",\"meta\":{\"id\":\"action\"},\"error\":\"StandardError\",\"info\":{\"key1\":\"ValueOne\",\"key2\":[\"An\",\"Array\"]},\"pid\":9973}
",
          layout.format(event)
        )
      end

      it 'log entry from error with a backtrace' do
        error = StandardError.new
        backtrace = ["a fake", "backtrace"]
        error.set_backtrace(backtrace)
        event = stub(:data => [{:id => "action"}, "Yet Another Message", error], :time => Time.new(1979,4,9), :level => 3)
        assert_equal("{\"time\":\"1979-04-09 00:00:00.000000\",\"level\":\"error\",\"action_id\":\"action\",\"message\":\"Yet Another Message\",\"meta\":{\"id\":\"action\"},\"error\":\"StandardError\",\"pid\":9973}
",
          layout.format(event)
        )
      end
    end
  end
end
