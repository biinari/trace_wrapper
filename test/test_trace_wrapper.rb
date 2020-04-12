# frozen_string_literal: true

$LOAD_PATH << File.expand_path('../lib', __dir__)

require 'minitest/autorun'
require 'minitest/pride'

require 'trace_wrapper'
require File.expand_path('playground', __dir__)

class TestTraceWrapper < Minitest::Test
  class Output
    attr_reader :output

    def initialize
      @output = []
    end

    def write(text)
      text = text.to_s unless text.is_a?(String)
      @output << text
    end
  end

  ::TraceWrapper::COLOURS.each do |k, v|
    const_set(k.upcase, v)
  end
  RETURN = "#{YELLOW}return#{CLEAR}"

  def strip_colour(text)
    text.gsub(/\e\[(?:1;)?\d+m/, '')
  end

  def assert_equal_output(expected_output, **tracer_options)
    output = Output.new
    opts = tracer_options.merge(output: output)
    tracer = ::TraceWrapper.new(**opts)
    yield(tracer)

    assert_equal(expected_output, output.output.join)
  ensure
    tracer.unwrap
  end

  def test_wrap_output_module
    mod_name = "#{GREEN}PlayModule#{CLEAR}"

    expected_output = <<-OUTPUT.gsub(/^ {4}/, '')
      MOD.TWO()
        MOD.ONE(#{PURPLE}"abc"#{CLEAR})
        MOD.ONE RETURN #{PURPLE}"abc and a one"#{CLEAR}
      MOD.TWO RETURN #{PURPLE}"abc and a one"#{CLEAR}
    OUTPUT
    expected_output.gsub!('MOD', mod_name)
                   .gsub!('RETURN', RETURN)
                   .gsub!('ONE', "#{BLUE}one#{CLEAR}")
                   .gsub!('TWO', "#{BLUE}two#{CLEAR}")

    subject = lambda do |tracer|
      tracer.wrap(PlayModule, method_type: :methods)
      result = PlayModule.two do
        PlayModule.one('abc')
      end

      assert_equal('abc and a one', result)
    end

    assert_equal_output(strip_colour(expected_output), colour: false, &subject)
    assert_equal_output(expected_output, colour: true, &subject)
  end

  def test_wrap_output_class
    cls_name = "#{GREEN}PlayClass#{CLEAR}"

    expected_output = <<-OUTPUT.gsub(/^ {4}/, '')
      CLASS.PLAY_HELLO()
        CLASS#PLAY(#{PURPLE}"hello"#{CLEAR}, #{PURPLE}"world"#{CLEAR})
        CLASS#PLAY RETURN #{PURPLE}"hello, world"#{CLEAR}
      CLASS.PLAY_HELLO RETURN #{PURPLE}"hello, world"#{CLEAR}
    OUTPUT
    expected_output.gsub!('CLASS', cls_name)
                   .gsub!('RETURN', RETURN)
                   .gsub!('PLAY_HELLO', "#{BLUE}play_hello#{CLEAR}")
                   .gsub!('PLAY', "#{BLUE}play#{CLEAR}")

    subject = lambda do |tracer|
      tracer.wrap(PlayClass)
      result = PlayClass.play_hello

      assert_equal('hello, world', result)
    end

    assert_equal_output(strip_colour(expected_output), colour: false, &subject)
    assert_equal_output(expected_output, colour: true, &subject)
  end

  def test_wrap_output_class_nesting
    cls_name = "#{GREEN}PlayFib#{CLEAR}"
    fib = "#{BLUE}fib#{CLEAR}"

    expected_output = <<-OUTPUT.gsub(/^ {4}/, '')
      SIG(ARG(4))
        SIG(ARG(3))
          SIG(ARG(2))
            SIG(ARG(1))
            SIG RETURN ARG(1)
            SIG(ARG(0))
            SIG RETURN ARG(1)
          SIG RETURN ARG(2)
          SIG(ARG(1))
          SIG RETURN ARG(1)
        SIG RETURN ARG(3)
        SIG(ARG(2))
          SIG(ARG(1))
          SIG RETURN ARG(1)
          SIG(ARG(0))
          SIG RETURN ARG(1)
        SIG RETURN ARG(2)
      SIG RETURN ARG(5)
    OUTPUT
    expected_output.gsub!('SIG', "#{cls_name}##{fib}")
                   .gsub!('RETURN', RETURN)
                   .gsub!(/ARG\((\d+)\)/, "#{PURPLE}\\1#{CLEAR}")

    subject = lambda do |tracer|
      tracer.wrap(PlayFib, method_type: :instance_methods)
      result = PlayFib.new.fib(4)

      assert_equal(5, result)
    end

    assert_equal_output(strip_colour(expected_output), colour: false, &subject)
    assert_equal_output(expected_output, colour: true, &subject)
  end
end
