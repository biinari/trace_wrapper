# TraceWrapper method call / return tracing

TraceWrapper outputs method call and return info for a class or module

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'trace_wrapper'
```

Or install it generally with:

```sh
$ gem install trace_wrapper
```

## Usage

A simple example of a module and a class to be traced:

```ruby
module MyModule
  module_function

  def something_else
    puts 'What else?'
  end
end

class MyClass
  def self.forty(two: 2)
    40 + two
  end

  def plus_two(x)
    x + 2
  end
end
```

A basic example of tracing our sample class and module:

```ruby
TraceWrapper.wrap(MyClass, MyModule) do
  puts MyModule.subject
  puts MyClass.meaning(x: 40)
end
```

Will output the following (with the tracing all indented by at least 2 spaces):

```
  MyModule.subject()
  MyModule.subject return "What is the answer …"
What is the answer to the ultimate question?
  MyClass.meaning(x: 40)
    MyClass#plus_two(40)
    MyClass#plus_two return 42
  MyClass.meaning return 42
42
```

See [custom example](examples/custom.rb) for a more custom usage

### Options

Options for `TraceWrapper.new`

* `:colour` - Enable coloured output (default: `nil` automatically enables colour if output is a TTY)
* `:output` - Specify output `IO` (default: `STDOUT`)

Options for `TraceWrapper#wrap`

* `:method_type` - Which type of methods to wrap

It is also supported to run `TraceWrapper.wrap` with options available to `.new` and the instance method `#wrap`.

Sample usage with all options:

```ruby
tracer = TraceWrapper.new(colour: true, output: STDERR)
tracer.wrap(MyClass, method_type: :instance_methods)
MyClass.new.plus_two(40)
tracer.unwrap

# or in a single call
TraceWrapper.wrap(MyClass, colour: false, method_type: :methods) do
  MyClass.meaning(x: 40)
end
```

## Testing

Run the tests with `rake` or directly with:

```ruby
bundle exec ruby test/test_trace_wrapper.rb
```

## Contributing

1. Fork it
2. Create your feature branch
3. Commit your changes
4. Push to your branch
5. Create a Pull Request
