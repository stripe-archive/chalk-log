# Chalk::Log

`Chalk::Log` adds a logger object to any class, which can be used for
unstructured or semi-structured logging. Use it as follows:

```ruby
class A
  include Chalk::Log
end

A.log.info('hello', key: 'value')
#=> [2013-06-18 22:18:28.314756] [64682] hello: key="value"
```

The output is both human-digestable and easily parsed by log indexing
systems such as [Splunk](http://www.splunk.com/) or
[Logstash](http://logstash.net/).

It can also pretty-print exceptions for you:

```ruby
module A; include Chalk::Log; end
begin; raise "hi"; rescue => e; end
A.log.error('Something went wrong', e)
#=> Something went wrong: hi (RuntimeError)
#     (irb):8:in `irb_binding'
#     /Users/gdb/.rbenv/versions/1.9.3-p362/lib/ruby/1.9.1/irb/workspace.rb:80:in `eval#     /Users/gdb/.rbenv/versions/1.9.3-p362/lib/ruby/1.9.1/irb/workspace.rb:80:in `evaluate'
#     /Users/gdb/.rbenv/versions/1.9.3-p362/lib/ruby/1.9.1/irb/context.rb:254:in `evaluate'
#     /Users/gdb/.rbenv/versions/1.9.3-p362/lib/ruby/1.9.1/irb.rb:159:in `block (2 levels) in eval_input'
#     [...]
```

The log methods accept a message and/or an exception and/or an info
hash (if multiple are passed, they must be provided in that
order). The log methods will never throw an exception, but will
instead print an log message indicating they had a fault.

## Overview

Including `Chalk::Log` creates a `log` method as both a class an
instance method, which returns a class-specific logger.

By default, it tags loglines with auxiliary information: a
microsecond-granularity timestamp, the PID, and an action_id (which
should tie together all lines for a single logical action in your
system, such as a web request).

You can turn off tagging, or just turn off timestamping, through
appropriate configatron settings (see [config.yaml](/config.yaml)).

There are also two `LSpace` dynamic settings available:

- `LSpace[:action_id]`: Set the action_id dynamically for this action. (This is used automatically by things like `Chalk::Web` which have a well-defined action.)
- `LSpace[:'chalk.log.disabled']`: Disable all logging.

You can use `LSpace` settings as follows:

```ruby
class A; include Chalk::Log; end
foo = A.new

LSpace.with(action_id: 'request-123') do
  foo.log.info('Test')
  #=> [2014-05-26 01:12:28.485822] [47325|request-123] Test
end
```

## Log methods

`Chalk::Log` provides five log levels:

    debug, info, warn, error, fatal

## Inheritance

`Chalk::Log` makes a heroic effort to ensure that inclusion chaining
works, so you can do things like:

```ruby
module A
  include Chalk::Log
end

module B
 include A
end

class C
  include B
end
```

and still have `C.log` and `C.new.log` work. (Normally you'd expect
for the class-method version to be left behind.)

## Best practices

- You should never use string interpolation in your log
  message. Instead, always use the structured logging keys. So for
  example:

```ruby
# Bad
log.info("Just printed #{lines.length} lines")
# Good
log.info("Printed", lines: lines.length)
```

- Don't end messages with a punctuation -- `Chalk::Log` will
  automatically add a colon if an info hash is provided; if not, it's
  fine to just end without trailing punctutaion. Case in point

- In most projects, you'll find most of your classes start including
  `Chalk::Log` -- it's pretty cheap to add it, and it's quite
  lightweight to use. (In contrast, there's no good way to autoinclude
  it, since that would likely break many classes which aren't
  expecting a magical `log` method to appear.)

## Limitations

`Chalk::Log` is not very configurable. Our usage at Stripe tends to be
fairly opinionated, so there hasn't been much demand for increased
configurability. We would be open to making it less rigid,
however. (In any case, under the hood `Chalk::Log` is just using the
`logging` gem, so if the need arises it wouldn't be hard to acquire
the full flexibility of `logging`.)
