# Chalk::Log

Chalk::Log makes any class loggable. It can be used for structured
and unstructured logging.

## Overview

Use Chalk::Log as follows:

    module A
      include Chalk::Log
      log.info('hello', :key => 'value')
    end
    #=> [2013-06-18 22:18:28.314756] [64682] hello: key="value"

Chalk::Log will create a `log` method as both a class an instance
method, which return a class-specific logger.

By default, it tags loglines with helpful information. You can disable
tagging using the following:

    Chalk::Log::Config[:tagging_disabled] = true

Chalk::Log makes efforts to ensure that inclusion chaining works, so you
can do things like:

    module A
      include Chalk::Log
    end

    module B
      include A
    end

    class C
      include B
    end

and still have `C.log` and `C.new.log` work.

You can also log errors nicely:

    module A; include Chalk::Log; end
    begin; raise "hi"; rescue => e; end
    A.log.error('Something went wrong', e)
    #=> Something went wrong: hi (RuntimeError)
    #     (irb):8:in `irb_binding'
    #     /Users/gdb/.rbenv/versions/1.9.3-p362/lib/ruby/1.9.1/irb/workspace.rb:80:in `eval'
    #     /Users/gdb/.rbenv/versions/1.9.3-p362/lib/ruby/1.9.1/irb/workspace.rb:80:in `evaluate'
    #     /Users/gdb/.rbenv/versions/1.9.3-p362/lib/ruby/1.9.1/irb/context.rb:254:in `evaluate'
    #     /Users/gdb/.rbenv/versions/1.9.3-p362/lib/ruby/1.9.1/irb.rb:159:in `block (2 levels) in eval_input'
    #     /Users/gdb/.rbenv/versions/1.9.3-p362/lib/ruby/1.9.1/irb.rb:273:in `signal_status'
    #     /Users/gdb/.rbenv/versions/1.9.3-p362/lib/ruby/1.9.1/irb.rb:156:in `block in eval_input'
    #     [backtrace truncated: 7 / 17 lines]

Chalk::Log provides are five log levels:

    debug, info, warn, error, fatal

## Limitations

Chalk::Log is not very configurable. Our usage at Stripe tends to
be fairly opinionated, so there hasn't been much demand for increased
configurability. That being said, making it configurable shouldn't be
hard (Chalk::Log is mostly a layer over the `logging` gem).
