require 'logging'

# Include Chalk::Log in a class or module to make that class (and all
# subclasses / includees) loggable.  This creates a class and instance
# 'log' method which you can call from within your loggable class.
#
# Loggers are per-class and can be manipulated as you'd expect:
#
# class A
#   include Chalk::Log
#   log.level = 'DEBUG'
#   log.debug('Now you see me!')
#   log.level = 'INFO'
#   log.debug('Now you do not!')
# end
module Chalk::Log
  LEVELS = [:debug, :info, :warn, :error, :ann, :fatal]

  @@chalk_logger_modules = {}

  def self.chalk_logger_modules
    @@chalk_logger_modules
  end

  def self.included(other)
    other.extend(ClassMethods)
    if other.instance_of?(Module)
      other.class_eval do
        chalk_logger_modules = Chalk::Log.chalk_logger_modules
        break if chalk_logger_modules.include?(self)

        chalk_logger_modules[self] = {
          :included => method(:included),
          :extended => method(:extended)
        }

        def self.included(other)
          other.send(:include, Chalk::Log)
          config = Chalk::Log.chalk_logger_modules[self]
          raise "Missing chalk-log module config for #{self}" unless config
          config[:included].call(other)
        end

        def self.extended(other)
          other.send(:include, Chalk::Log)
          config = Chalk::Log.chalk_logger_modules[self]
          raise "Missing chalk-log module config for #{self}" unless config
          config[:extended].call(other)
        end
      end
    end
  end

  def self.init
    return if @inited

    ::Logging.init(*LEVELS)
    # We've a fork where Logging doesn't swallow errors; use that if
    # possible.
    ::Logging.raise_errors(true) if ::Logging.respond_to?(:raise_errors)
    ::Logging.logger.root.add_appenders(
      ::Logging.appenders.stderr(:layout => layout)
      )
    Chalk::Log::Logger.init

    @inited = true
  end

  def self.layout
    @layout ||= Chalk::Log::Layout.new
  end

  module ClassMethods
    def log
      @log ||= Chalk::Log::Logger.new(self.name)
    end
  end

  include ClassMethods

  # See the "correctly make the end class loggable when it has
  # already included loggable" test for why it's implemented like
  # this. (Need to handle the case where someone has already
  # included me, and then clobbered the class implementations via an
  # extend.) Hence we do this "defer to class, unless I am a class"
  # logic.
  log = instance_method(:log)
  define_method(:log) do
    if self.kind_of?(Class)
      log.bind(self).call
    else
      self.class.log
    end
  end
end

require 'chalk-log/config'
require 'chalk-log/logger'
require 'chalk-log/layout'
require 'chalk-log/utils'
