# frozen_string_literal: true

require_relative '../lib/trace_wrapper'

module MyModule
  module_function

  def subject
    'What is the answer to the ultimate question?'
  end
end

class MyClass
  def self.meaning(x: 1)
    new.plus_two(x)
  end

  def plus_two(x)
    x + 2
  end
end

tracer = TraceWrapper.new(colour: false, output: STDERR)
tracer.wrap(MyModule, method_type: :methods)
tracer.wrap(MyClass, method_type: :all)

puts MyModule.subject
puts MyClass.meaning(x: 40)

tracer.unwrap
