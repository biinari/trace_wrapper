# frozen_string_literal: true

require 'trace_wrapper/version'
require 'trace_wrapper/shell'

##
# Wraps methods on given classes or modules to output a call/return tree.
class TraceWrapper
  include TraceWrapper::Shell

  class << self
    ##
    # Wraps methods on given +receivers+ with tracing
    #
    # options will be passed to .new and #wrap respectively
    #
    # If a block is given, it will be passed to #wrap
    def wrap(*receivers, **options, &block) # :yields: a_trace_wrapper
      init_keys = %i[output colour]
      init_args = options.select { |k, _| init_keys.include?(k) }
      wrap_args = options.reject { |k, _| init_keys.include?(k) }

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
  # output is a TTY)
  def initialize(output: $stdout, colour: nil)
    @output = output
    @colour = colour
    @unwrappers = []
    @main_process_id = process_id
    @processes = {}
    process
  end

  ##
  # Wraps methods on given +receivers+ with tracing
  #
  # Options
  #
  # +:method_type+ - Types of methods to wrap (default: +:all+). Choices are:
  # +:instance+ (for instance methods),
  # +:self+ (for receiver methods, i.e. class/module functions),
  # +:all+ for both
  #
  # +:visibility+ - Lowest method visibility level to wrap
  # (default: +:protected+). Choices are: :public, :protected, :private.
  #
  # If a block is given, the wrappers will be created just around the block and
  # the block's result will be returned.
  # The TraceWrapper instance will be yielded to the block to allow further
  # wraps to be added.
  #
  # If no block is given, you should call unwrap after use.
  def wrap(*receivers,
           method_type: :all,
           visibility: :protected) # :yields: a_trace_wrapper
    unwrappers = []
    Array(*receivers).each do |receiver|
      if %i[all self].include?(method_type)
        unwrappers += wrap_methods(receiver, visibility: visibility)
      end
      if %i[all instance].include?(method_type)
        unwrappers += wrap_instance_methods(receiver, visibility: visibility)
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
  def wrap_methods(*receivers, visibility: :protected)
    unwrappers = []
    Array(*receivers).each do |receiver|
      mod, unwrapper = wrapping_module(receiver, :self, visibility)
      unwrappers << unwrapper
      receiver.singleton_class.send(:prepend, mod)
    end
    unwrappers
  end

  # Wrap instance methods (called on an instance of the class given) with
  # tracing
  def wrap_instance_methods(*receivers, visibility: :protected)
    unwrappers = []
    Array(*receivers).each do |receiver|
      mod, unwrapper = wrapping_module(receiver, :instance, visibility)
      unwrappers << unwrapper
      receiver.send(:prepend, mod)
    end
    unwrappers
  end

  def wrapping_module(receiver, method_type, visibility)
    method_names = get_methods(receiver, method_type, visibility)
    get_method = method_type == :instance ? :instance_method : :method
    dot = method_type == :instance ? '#' : '.'
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

  LIST_METHODS = {
    instance: {
      public: :public_instance_methods,
      protected: :protected_instance_methods,
      private: :private_instance_methods
    },
    self: {
      public: :public_methods,
      protected: :protected_methods,
      private: :private_methods
    }
  }.freeze # :nodoc:

  def get_methods(receiver, method_type, visibility)
    visibilities = %i[public protected private]
    unless visibilities.include?(visibility)
      raise "visibility option not recognised: #{visibility.inspect}"
    end
    visibilities = visibilities[0..visibilities.find_index(visibility)]

    visibilities.map do |vis|
      lister = LIST_METHODS[method_type][vis]
      receiver.public_send(lister, false) - Object.public_send(lister)
    end.compact.flatten
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
    return if process_id == @main_process_id
    pid, tid = process_id
    return pid if Thread.current == Thread.main
    pid = '' if pid == @main_process_id.first
    "#{pid}:#{tid.to_s[-4..-1]}"
  end

  def show_pid
    return if process_id == @main_process_id
    colour("[#{process_label}]", process[:colour])
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
