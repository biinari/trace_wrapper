# frozen_string_literal: true

##
# Wraps methods on given classes or modules to output a call/return tree.
class TraceWrapper
  COLOURS = {
    red: '31m',
    b_red: '1;31m',
    green: '32m',
    b_green: '1;32m',
    orange: '33m',
    yellow: '1;33m',
    blue: '34m',
    b_blue: '1;34m',
    purple: '35m',
    b_purple: '1;35m',
    teal: '36m',
    cyan: '1;36m'
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
    @unwrappers = []
    @process_id = process_id
    @processes = {}
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
    get_method = methods_type == :methods ? :method : :instance_method
    dot = methods_type == :methods ? '.' : '#'
    trace_call = method(:trace_call)
    trace_return = method(:trace_return)
    key_args = method(:key_args?)

    mod = Module.new do
      method_names.each do |name|
        wrap_method =
          if key_args.call(receiver.public_send(get_method, name))
            lambda do |*args, **kwargs, &block|
              trace_call.call(receiver, dot, name, *args, **kwargs)
              result = super(*args, **kwargs, &block)
              trace_return.call(receiver, dot, name, result)
              result
            end
          else
            lambda do |*args, &block|
              trace_call.call(receiver, dot, name, *args)
              result = super(*args, &block)
              trace_return.call(receiver, dot, name, result)
              result
            end
          end
        define_method(name, wrap_method)
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
    writeln("#{show_pid}#{function(receiver, dot, method_name)}" \
            "(#{show_args(*args, **kwargs)})")
    incr_indent
  end

  def trace_return(receiver, dot, method_name, result)
    decr_indent
    writeln("#{show_pid}#{function(receiver, dot, method_name)} " \
            "#{colour('return', :yellow)} " \
            "#{colour(short_inspect(result), :purple)}")
  end

  def key_args?(method)
    method.parameters.any? { |k, _| %i[keyrest key].include?(k) }
  end

  def main
    TOPLEVEL_BINDING.receiver
  end

  def function(receiver, dot, name)
    return colour(id, :teal) if main == receiver

    "#{colour(receiver, :b_green)}#{dot}#{colour(name, :teal)}"
  end

  def writeln(text)
    @output.write("#{indent}#{text}\n")
  end

  def colour(text, colour)
    return text unless colour?
    "\e[#{COLOURS[colour]}#{text}\e[0m"
  end

  def colour?
    return @colour unless @colour.nil?
    @output.respond_to?(:isatty) && @output.isatty
  end

  def incr_indent
    process[:indent] += 1
  end

  def decr_indent
    process[:indent] = [process[:indent] - 1, 0].max
  end

  def indent
    '  ' * (process[:indent] + 1)
  end

  def process
    proc_colours = %i[b_purple orange blue red purple cyan yellow b_blue b_red]
    @processes[process_id.join(':')] ||= {
      colour: proc_colours[@processes.size],
      indent: 0
    }
  end

  def process_id
    [Process.pid, Thread.current.hash]
  end

  def process_label
    return if process_id == @process_id
    pid, tid = process_id
    return pid if Thread.current == Thread.main
    pid = '' if pid == @process_id.first
    "#{pid}:#{tid.to_s[-4..-1]}"
  end

  def show_pid
    colour("[#{process_label}]", process[:colour]) if process_id != @process_id
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
