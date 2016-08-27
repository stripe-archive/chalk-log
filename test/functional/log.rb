require File.expand_path('../_lib', __FILE__)

require 'chalk-log'

module Critic::Functional
  class LogTest < Test
    def self.add_appender
      unless @appender
        @appender = ::Logging.appenders.string_io(
          'test-stringio',
          layout: Chalk::Log.layout
        )
        ::Logging.logger.root.add_appenders(@appender)
      end
      @appender
    end

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
    end

    class TestLogInstanceMethods < Test
      include Chalk::Log

      before do
        TestLogInstanceMethods.log.level = 'INFO'
        Chalk::Log.init
        @appender = LogTest.add_appender
      end

      def assert_logged(expected_string, *args)
        assert_includes(@appender.sio.string, expected_string, *args)
      end

      it 'accepts blocks on instance methods' do
        called = false
        log.debug { assert(false, "DEBUG block called at INFO") }
        log.info { called = true; "" }
        assert(called, "INFO block not called at INFO level")
      end

      describe 'when contextual info is set' do

        it 'adds contextual information to `.info` log lines' do
          log.with_contextual_info(key: 'value') {log.info("message")}
          assert_logged("key=value")
        end

        it 'nests contexts' do
          log.with_contextual_info(top_key: "top_value") do
            log.info("top message")
            log.with_contextual_info(inner_key: "inner_value") do
              log.info("inner message")
            end
          end
          %w{top_key=top_value inner_key=inner_value}.each do |pair|
            assert_logged(pair)
          end
        end

        it 'prefers explicit information over the context' do
          log.with_contextual_info(key: 'value') {log.info("message", key: 'inner')}
          assert_logged("key=inner")
        end

        it 'requires a block' do
          exn = assert_raises(ArgumentError) do
            log.with_contextual_info(i_am_not: "passing a block")
          end
          assert_includes(exn.message, "Must pass a block")
        end

        it 'requires its argument must be a hash' do
          exn = assert_raises(TypeError) do
            log.with_contextual_info('not a hash') {}
          end
          assert_includes(exn.message, 'must be a Hash')
        end
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
  end
end
