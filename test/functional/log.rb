require File.expand_path('../_lib', __FILE__)

require 'chalk-log'

module Critic::Functional
  class LogTest < Test
    before do
      Chalk::Log.init
    end

    describe 'when a class has included Log' do
      it 'instances are loggable' do
        class MyClass
          include Chalk::Log
        end

        MyClass.new.log.info("Hi!")
      end

      it 'the class is loggable' do
        class YourClass
          include Chalk::Log
        end

        YourClass.log.info("Hi!")
      end
    end

    describe 'including a loggable module into another' do
      describe 'the inclusions are straightline' do
        it 'make the includee loggable' do
          module LogTestA
            include Chalk::Log
          end

          module LogTestB
            include LogTestA
          end

          assert(LogTestB < Chalk::Log)
          assert(LogTestB.respond_to?(:log))
        end

        it 'preserves any custom include logic prior to Log inclusion' do
          module CustomLogTestA
            def self.dict=(dict)
              @dict = dict
            end

            def self.dict
              @dict
            end

            def self.included(other)
              dict['included'] = true
            end

            include Chalk::Log
          end

          dict = {}
          CustomLogTestA.dict = dict

          module CustomLogTestB
            include CustomLogTestA
          end

          assert(CustomLogTestB < Chalk::Log)
          assert(CustomLogTestB.respond_to?(:log))
          assert_equal(true, dict['included'])
        end

        # TODO: it'd be nice if this weren't true, but I'm not sure
        # how to get a hook when a method is overriden.
        it 'custom include logic after Log inclusion clobbers the default include logic' do
          module CustomLogTestC
            def self.dict=(dict)
              @dict = dict
            end

            def self.dict
              @dict
            end

            include Chalk::Log

            def self.included(other)
              dict['included'] = true
            end
          end

          dict = {}
          CustomLogTestC.dict = dict

          module CustomLogTestD
            include CustomLogTestC
          end

          assert(CustomLogTestD < Chalk::Log)
          assert(!CustomLogTestD.respond_to?(:log))
          assert_equal(true, dict['included'])
        end
      end
    end

    describe 'extending a Log module into another' do
      describe 'the inclusions are straightline' do
        it 'make the extendee loggable' do
          module ExtendLogTestA
            include Chalk::Log
          end

          module ExtendLogTestB
            extend ExtendLogTestA
          end

          assert(ExtendLogTestB < Chalk::Log)
          assert(ExtendLogTestB.respond_to?(:log))
        end
      end
    end

    describe 'when a class is loggable' do
      class MyLog
        include Chalk::Log
      end

      it 'log.warn works' do
        msg = 'msg'
        # For some reason this isn't working:
        MyLog.log.backend.expects(:warn).once
        MyLog.log.warn(msg)
      end

      it 'log.info works' do
        msg = 'msg'
        MyLog.log.backend.expects(:info).once
        MyLog.log.info(msg)
      end

      it 'accepts blocks' do
        class LogTestE
          include Chalk::Log
        end
        LogTestE.log.level = "INFO"

        LogTestE.log.debug { assert(false, "DEBUG block called when at INFO level") }
        called = false
        LogTestE.log.info { called = true; "" }
        assert(called, "INFO block not called at INFO level")
      end

      it 'log.error formats correctly' do
        # TODO: capture the output string
        msg = 'message'
        begin
          raise "foo"
        rescue => e
        end
        MyLog.log.error('message', e)
        MyLog.log.error(e)
      end

      it 'log.error does not assert if passed a nil exception' do
        Chalk::Log::Layout.any_instance.expects(:maybe_assert).never
        MyLog.log.error('message', nil)
      end
    end

    class TestLogInstanceMethods < Test
      include Chalk::Log

      before do
        TestLogInstanceMethods.log.level = 'INFO'
        Chalk::Log.init
      end

      it 'accepts blocks on instance methods' do
        called = false
        log.debug { assert(false, "DEBUG block called at INFO") }
        log.info { called = true; "" }
        assert(called, "INFO block not called at INFO level")
      end
    end

    describe 'when chaining includes and extends' do
      it 'correctly make the end class loggable' do
        module Base1
          include Chalk::Log
        end

        class Child1
          extend Base1
        end

        Child1.log.info("Hello!")
        assert(true)
      end

      it 'correctly make the end class loggable when chaining an include and extend' do
        module Base2
          include Chalk::Log
        end

        module Middle2
          extend Base2
        end

        class Child2
          include Middle2
        end

        Child2.log.info("Hello!")
        assert(true)
      end

      it 'correctly make the end class loggable when chaining an extend and an extend' do
        module Base3
          include Chalk::Log
        end

        module Middle3
          extend Base3
        end

        class Child3
          extend Middle3
        end

        Child3.log.info("Hello!")
        assert(true)
      end

      it 'correctly make the end class loggable when it has already included loggable' do
        module Base4
          include Chalk::Log
        end

        module Middle4
          extend Base4
        end

        class Child4
          include Chalk::Log
          extend Middle4
        end

        Child4.log.info("Hello!")
        assert(true)
      end
    end

    it 'correctly makes a module loggable' do
      module Base5
        include Chalk::Log
      end

      Base5.log.info("Hello!")
      assert(true)
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
        assert_equal('time="1979-04-09 00:00:00.000000" message="Another Message" level=3 bad=true pid=9973 error=StandardError error_class=StandardError backtrace="' +
          "\n" + '  (no backtrace)' +
          "\n" + '  "' + "\n",
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
        assert_equal('time="1979-04-09 00:00:00.000000" message="Yet Another Message" level=3 bad=true pid=9973 error=StandardError error_class=StandardError backtrace="' +
          "\n" + '  a fake' +
          "\n" + '    backtrace' +
          "\n" + '  "' + "\n",
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
