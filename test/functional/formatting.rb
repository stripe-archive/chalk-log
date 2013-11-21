require File.expand_path('../_lib', __FILE__)

require 'chalk-log'

module Critic::Functional
  class LogTest < Test
    before do
      Chalk::Log.init
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
      class PrettyPrintLogger
        include Chalk::Log
      end
      Chalk::Log::Config.update(:tag_with_timestamp => false)

      layout = PrettyPrintLogger::Layout.new

      it 'log entry from info' do
        event = stub(:data => ["A Message", {:key1 => "ValueOne", :key2 => ["An", "Array"]}], :time => Time.new(1979,4,9), :level => 1)
        Process.stubs(:pid).returns(9973)
        layout.stubs(:output_format => 'pp')
        assert_equal('[9973] A Message: key1=ValueOne key2=["An","Array"]' + "\n",
          layout.format(event)
        )
      end

      it 'log entry from error without a backtrace' do
        event = stub(:data => ["Another Message", StandardError.new], :time => Time.new(1979,4,9), :level => 3)
        Process.stubs(:pid).returns(9973)
        layout.stubs(:output_format => 'pp')
        assert_equal('[9973] Another Message: StandardError (StandardError)' +
          "\n" + '[9973]   (no backtrace)' + "\n",
          layout.format(event)
        )
      end

      it 'log entry from error with a backtrace' do
        error = StandardError.new
        backtrace = ["a fake", "backtrace"]
        error.set_backtrace(backtrace)
        event = stub(:data => ["Yet Another Message", error], :time => Time.new(1979,4,9), :level => 3)
        Process.stubs(:pid).returns(9973)
        layout.stubs(:output_format => 'pp')
        assert_equal('[9973] Yet Another Message: StandardError (StandardError)' +
          "\n" + '[9973]   a fake' +
          "\n" + '[9973]   backtrace' + "\n",
          layout.format(event)
        )
      end
    end

    describe 'generates a kv' do
      class KVLogger
        include Chalk::Log
      end

      layout = KVLogger::Layout.new

      it 'log entry from info' do
        event = stub(:data => ["A Message", {:key1 => "ValueOne", :key2 => ["An", "Array"]}], :time => Time.new(1979,4,9), :level => 1)
        Process.stubs(:pid).returns(9973)
        layout.stubs(:output_format).returns('kv')
        assert_equal('time="1979-04-09 00:00:00.000000" message="A Message" level=1 bad=false pid=9973 key1=ValueOne key2=["An","Array"]' + "\n",
          layout.format(event)
        )
      end

      it 'log entry from error without a backtrace' do
        event = stub(:data => ["Another Message", StandardError.new], :time => Time.new(1979,4,9), :level => 3)
        Process.stubs(:pid).returns(9973)
        layout.stubs(:output_format).returns('kv')
        assert_equal('time="1979-04-09 00:00:00.000000" message="Another Message" level=3 bad=true pid=9973 error=StandardError error_class=StandardError backtrace=' +
          "\n" + '  "(no backtrace)"' +
          "\n",
          layout.format(event)
        )
      end

      it 'log entry from error with a backtrace' do
        error = StandardError.new
        backtrace = ["a fake", "backtrace"]
        error.set_backtrace(backtrace)
        event = stub(:data => ["Yet Another Message", error], :time => Time.new(1979,4,9), :level => 3)
        Process.stubs(:pid).returns(9973)
        layout.stubs(:output_format).returns('kv')
        assert_equal('time="1979-04-09 00:00:00.000000" message="Yet Another Message" level=3 bad=true pid=9973 error=StandardError error_class=StandardError backtrace=' +
          "\n" + '  "a fake' +
          "\n" + '    backtrace"' +
          "\n",
          layout.format(event)
        )
      end
    end

    describe 'generates a json' do
      class JSONLogger
        include Chalk::Log
      end
      layout = JSONLogger::Layout.new

      it 'log entry from info' do
        event = stub(:data => ["A Message", {:key1 => "ValueOne", :key2 => ["An", "Array"]}], :time => Time.new(1979,4,9), :level => 1)
        Process.stubs(:pid).returns(9973)
        layout.stubs(:output_format).returns('json')
        assert_equal('{"time":"1979-04-09 00:00:00.000000","message":"A Message","info":{"key1":"ValueOne","key2":["An","Array"]},"level":1,"bad":false,"pid":9973}' + "\n",
          layout.format(event)
        )
      end

      it 'log entry from error without a backtrace' do
        event = stub(:data => ["Another Message", StandardError.new], :time => Time.new(1979,4,9), :level => 3)
        Process.stubs(:pid).returns(9973)
        layout.stubs(:output_format).returns('json')
        assert_equal('{"time":"1979-04-09 00:00:00.000000","message":"Another Message","error":"StandardError","level":3,"bad":true,"pid":9973}' + "\n",
          layout.format(event)
        )
      end

      it 'log entry from error with a backtrace' do
        error = StandardError.new
        backtrace = ["a fake", "backtrace"]
        error.set_backtrace(backtrace)
        event = stub(:data => ["Yet Another Message", error], :time => Time.new(1979,4,9), :level => 3)
        Process.stubs(:pid).returns(9973)
        layout.stubs(:output_format).returns('json')
        assert_equal('{"time":"1979-04-09 00:00:00.000000","message":"Yet Another Message","error":"StandardError","level":3,"bad":true,"pid":9973}' + "\n",
          layout.format(event)
        )
      end
    end
  end
end
