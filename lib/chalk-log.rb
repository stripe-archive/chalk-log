require 'logging'
require 'lspace'
require 'set'

require 'chalk-config'
require 'chalk-log/version'

# Include `Chalk::Log` in a class or module to make that class (and
# all subclasses / includees / extendees) loggable. This creates a
# class and instance `log` method which you can call from within your
# loggable class.
#
# Loggers are per-class and can be manipulated as you'd expect:
#
# ```ruby
# class A
#   include Chalk::Log
#
#   log.level = 'DEBUG'
#   log.debug('Now you see me!')
#   log.level = 'INFO'
#   log.debug('Now you do not!')
# end
# ```
#
# You shouldn't need to directly access any of the methods on
# `Chalk::Log` itself.
module Chalk::Log
  require 'chalk-log/errors'
  require 'chalk-log/logger'
  require 'chalk-log/layout'
  require 'chalk-log/utils'

  # The set of available log methods. (Changing these is not currently
  # a supported interface, though if the need arises it'd be easy to
  # add.)
  LEVELS = [:debug, :info, :warn, :error, :fatal].freeze

  module CLevels
    Sheddable = :sheddable
    SheddablePlus = :sheddableplus
    Critical = :critical
    CriticalPlus = :criticalplus
  end

  @included = Set.new

  # Method which goes through heroic efforts to ensure that the whole
  # inclusion hierarchy has their `log` accessors.
  def self.included(other)
    if other == Object
      raise "You have attempted to `include Chalk::Log` onto Object. This is disallowed, since otherwise it might shadow any `log` method on classes that weren't expecting it (including, for example, `configatron.chalk.log`)."
    end

    # Already been through this ordeal; no need to repeat it. (There
    # shouldn't be any semantic harm to doing so, just a potential
    # performance hit.)
    return if @included.include?(other)
    @included << other

    # Make sure to define the .log class method
    other.extend(ClassMethods)

    # If it's a module, we need to make sure both inclusion/extension
    # result in virally carrying Chalk::Log inclusion downstream.
    if other.instance_of?(Module)
      other.class_eval do
        included = method(:included)
        extended = method(:extended)

        define_singleton_method(:included) do |other|
          other.send(:include, Chalk::Log)
          included.call(other)
        end

        define_singleton_method(:extended) do |other|
          other.send(:include, Chalk::Log)
          extended.call(other)
        end
      end
    end
  end

  # Public-facing initialization method for all `Chalk::Log`
  # state. Unlike most other Chalk initializers, this will be
  # automatically run (invoked on first logger instantiation). It is
  # idempotent.
  def self.init
    return if @init
    @init = true

    # Load relevant configatron stuff
    Chalk::Config.register(File.expand_path('../../config.yaml', __FILE__),
      raw: true)

    # The assumption is you'll pipe your logs through something like
    # [Unilog](https://github.com/stripe/unilog) in production, which
    # does its own timestamping.
    Chalk::Config.register_raw(chalk: {log: {timestamp: STDERR.tty?}})

    ::Logging.init(*LEVELS)
    ::Logging.logger.root.add_appenders(
      ::Logging.appenders.stderr(layout: layout)
      )

    Chalk::Log::Logger.init
  end

  # The default layout to use for the root `Logging::Logger`.
  def self.layout
    @layout ||= Chalk::Log::Layout.new
  end

  # Adds a prefix to all logging within the current LSpace context.
  def self.with_message_prefix(prefix, &blk)
    LSpace.with(:'chalk.log.message_prefix' => prefix, &blk)
  end

  def self.message_prefix
    LSpace[:'chalk.log.message_prefix']
  end

  def self.level=(lvl)
    _root_backend.level = lvl
  end

  def self.level
    _root_backend.level
  end

  # This should only be called from Chalk::Log::Logger
  def self._root_backend
    @root_backend ||= begin
      backend = ::Logging::Logger.new("CHALK_LOG_ROOT")
      if (level = configatron.chalk.log.default_level)
        backend.level = level
      end
      backend
    end
  end

  # Home of the backend `log` method people call; included *and*
  # extended everywhere that includes Chalk::Log.
  module ClassMethods
    # The backend `log` method exposed to everyone. (In practice, the
    # method people call directly is one wrapper above this.)
    #
    # Sets a `@__chalk_log` variable to hold the logger instance.
    def log
      @__chalk_log ||= Chalk::Log::Logger.new(self.name)
    end
  end

  # Make the `log` method inheritable.
  include ClassMethods

  # The technique here is a bit tricky. The same `log` implementation
  # defined on any class/module needs to be callable by either an instance or
  # the class/module itself. (See the "correctly make the end class loggable when it has
  # already included loggable" test for why. In particular, someone
  # may have already included me, and then clobbered the class/module
  # implementations by extending me.) Hence we do this "defer to
  # class, unless I am a class/module" logic.
  log = instance_method(:log)
  define_method(:log) do
    if self.kind_of?(Module)
      log.bind(self).call
    else
      self.class.log
    end
  end
end
