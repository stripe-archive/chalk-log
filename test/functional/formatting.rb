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
        event = stub(:data => ["A Message", {:key1 => "ValueOne", :key2 => ["An", "Array"]}], :time => Time.new(1979,4,9), :level => 1)
        assert_equal('[9973] A Message: key1=ValueOne key2=["An","Array"]' + "\n",
          layout.format(event)
        )
      end

      it 'log entry from error without a backtrace' do
        event = stub(:data => ["Another Message", StandardError.new], :time => Time.new(1979,4,9), :level => 3)
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
        layout.stubs(:output_format => 'pp')
        assert_equal('[9973] Yet Another Message: StandardError (StandardError)' +
          "\n" + '[9973]   a fake' +
          "\n" + '[9973]   backtrace' + "\n",
          layout.format(event)
        )
      end
    end

    describe 'generates a kv' do
      before do
        Chalk::Log::Config.update(:output_format => 'kv')
      end

      class KVLogger
        include Chalk::Log
      end

      layout = KVLogger::Layout.new

      it 'log entry from info' do
        event = stub(:data => ["A Message", {:key1 => "ValueOne", :key2 => ["An", "Array"]}], :time => Time.new(1979,4,9), :level => 1)
        assert_equal("time=\"1979-04-09 00:00:00.000000\" pid=9973 level=\"info\" message=\"A Message\" bad=false key1=ValueOne key2=[\"An\",\"Array\"]
",
          layout.format(event)
        )
      end

      it 'log entry from error without a backtrace' do
        event = stub(:data => ["Another Message", StandardError.new], :time => Time.new(1979,4,9), :level => 3)
        assert_equal("time=\"1979-04-09 00:00:00.000000\" pid=9973 level=\"error\" message=\"Another Message\" bad=true error=StandardError error_class=StandardError
",
          layout.format(event)
        )
      end

      it 'log entry from error with a backtrace' do
        error = StandardError.new
        backtrace = ["a fake", "backtrace"]
        error.set_backtrace(backtrace)
        event = stub(:data => ["Yet Another Message", error], :time => Time.new(1979,4,9), :level => 3)
        assert_equal("time=\"1979-04-09 00:00:00.000000\" pid=9973 level=\"error\" message=\"Yet Another Message\" bad=true error=StandardError error_class=StandardError backtrace=
  a fake
  backtrace
",
          layout.format(event)
        )
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
        event = stub(:data => ["A Message", {:key1 => "ValueOne", :key2 => ["An", "Array"]}], :time => Time.new(1979,4,9), :level => 1)
        assert_equal("{\"time\":\"1979-04-09 00:00:00.000000\",\"pid\":9973,\"level\":\"info\",\"message\":\"A Message\",\"bad\":false,\"info\":{\"key1\":\"ValueOne\",\"key2\":[\"An\",\"Array\"]}}
",
          layout.format(event)
        )
      end

      it 'log entry from error without a backtrace' do
        event = stub(:data => ["Another Message", StandardError.new], :time => Time.new(1979,4,9), :level => 3)
        assert_equal("{\"time\":\"1979-04-09 00:00:00.000000\",\"pid\":9973,\"level\":\"error\",\"message\":\"Another Message\",\"bad\":true,\"error\":\"StandardError\"}
",
          layout.format(event)
        )
      end

      it 'log entry from error with a backtrace' do
        error = StandardError.new
        backtrace = ["a fake", "backtrace"]
        error.set_backtrace(backtrace)
        event = stub(:data => ["Yet Another Message", error], :time => Time.new(1979,4,9), :level => 3)
        assert_equal("{\"time\":\"1979-04-09 00:00:00.000000\",\"pid\":9973,\"level\":\"error\",\"message\":\"Yet Another Message\",\"bad\":true,\"error\":\"StandardError\"}
",
          layout.format(event)
        )
      end
    end
  end
end
