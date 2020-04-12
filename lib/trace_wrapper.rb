# frozen_string_literal: true

##
# Wraps methods on given classes or modules to output a call/return tree.
class TraceWrapper
  COLOURS = {
    clear: "\e[0m",
    red: "\e[1;31m",
    green: "\e[1;32m",
    orange: "\e[33m",
    blue: "\e[36m",
    purple: "\e[35m",
    yellow: "\e[1;33m"
  }.freeze

  ELLIPSIS = "\u2026"

  class << self
    def wrap(*receivers, **kwargs, &block)
      init_keys = %i[output colour]
      init_args = kwargs.select { |k, _| init_keys.include?(k) }
      wrap_args = kwargs.reject { |k, _| init_keys.include?(k) }

      new(**init_args).wrap(*receivers, **wrap_args, &block)
    end
  end

  ##
  # Create a new +TraceWrapper+
  #
  # Options:
  #
  # :output - +IO+ object to write trace output to (default +STDOUT+)
  # :colour - True to use shell colours in output (default +nil+ will colour if
  #           output is a TTY)
  def initialize(output: $stdout, colour: nil)
    @output = output
    @colour = colour
    @level = 0
    @unwrappers = []
  end

  ##
  # Wraps methods on given +receivers+ with tracing
  #
  # Options
  #
  # :method_type - Types of methods to wrap (default: :all). Choices are:
  #                :instance_methods for methods on instances of receiver(s)
  #                :methods for methods called directly on the receiver(s)
  #                :all for both
  #
  # If a block is given, the wrappers will be created just around the block
  def wrap(*receivers, method_type: :all)
    unwrappers = []
    [*receivers].each do |receiver|
      if %i[all methods].include?(method_type)
        unwrappers += wrap_methods(receiver)
      end
      if %i[all instance_methods].include?(method_type)
        unwrappers += wrap_instance_methods(receiver)
      end
    end
    if block_given?
      begin
        yield(self)
      ensure
        unwrappers.each(&:call)
      end
    else
      @unwrappers += unwrappers
      self
    end
  end

  # Remove any wrappers set by this tracer
  def unwrap
    @unwrappers.each(&:call)
    @unwrappers = []
  end

  private

  # Wrap standard methods (methods on the object given) with tracing
  def wrap_methods(*receivers)
    unwrappers = []
    [*receivers].each do |receiver|
      mod, unwrapper = wrapping_module(receiver, :methods)
      unwrappers << unwrapper
      receiver.singleton_class.send(:prepend, mod)
    end
    unwrappers
  end

  # Wrap instance methods (called on an instance of the class given) with
  # tracing
  def wrap_instance_methods(*receivers)
    unwrappers = []
    [*receivers].each do |receiver|
      mod, unwrapper = wrapping_module(receiver, :instance_methods)
      unwrappers << unwrapper
      receiver.send(:prepend, mod)
    end
    unwrappers
  end

  def wrapping_module(receiver, methods_type)
    method_names = receiver.public_send(methods_type) - Object.methods
    dot = methods_type == :methods ? '.' : '#'
    trace_call = method(:trace_call)
    trace_return = method(:trace_return)

    mod = Module.new do
      method_names.each do |name|
        define_method(name, lambda do |*args, **kwargs, &block|
          trace_call.call(receiver, dot, name, *args, **kwargs)
          result = super(*args, **kwargs, &block)
          trace_return.call(receiver, dot, name, result)
          result
        end)
      end
    end
    unwrapper = lambda do
      method_names.each do |name|
        mod.send(:remove_method, name) if mod.method_defined?(name)
      end
    end
    [mod, unwrapper]
  end

  def trace_call(receiver, dot, method_name, *args, **kwargs)
    writeln("#{function(receiver, dot, method_name)}(#{show_args(*args, **kwargs)})")
    @level += 1
  end

  def trace_return(receiver, dot, method_name, result)
    @level = [@level - 1, 0].max
    writeln("#{function(receiver, dot, method_name)} " \
            "#{colour('return', :yellow)} " \
            "#{colour(short_inspect(result), :purple)}")
  end

  def main
    TOPLEVEL_BINDING.receiver
  end

  def function(receiver, dot, name)
    return colour(id, :blue) if main == receiver

    "#{colour(receiver, :green)}#{dot}#{colour(name, :blue)}"
  end

  def writeln(text)
    @output.write("#{indent}#{text}\n")
  end

  def colour(text, colour = :green)
    return text unless colour?
    "#{COLOURS[colour]}#{text}#{COLOURS[:clear]}"
  end

  def colour?
    return @colour unless @colour.nil?
    @output.respond_to?(:isatty) && @output.isatty
  end

  def indent
    '  ' * (@level + 1)
  end

  def show_args(*args, **kwargs)
    return if args.empty? && kwargs.empty?
    parts = args.map do |v|
      colour(short_inspect(v), :purple)
    end
    parts += kwargs.map do |k, v|
      "#{k}: #{colour(short_inspect(v), :purple)}"
    end
    parts.join(', ')
  end

  def short_inspect(obj, limit = 20)
    text = obj.inspect
    return text if text.length <= limit
    text[0...limit] + ELLIPSIS + text[-1]
  end
end
