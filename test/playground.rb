# frozen_string_literal: true

module PlayModule
  module_function

  def one(text)
    "#{text} and a one"
  end

  def two(*args, **kwargs)
    yield(*args, **kwargs)
  end
end

class PlayClass
  class << self
    def play_hello
      new.play('hello', 'world')
    end
  end

  def play(*args)
    args.map(&:to_s).join(', ')
  end

  def play_friendly(*args)
    friendly(*args)
  end

  def play_solitaire(*args)
    solitaire(*args)
  end

  protected

  def friendly(*args)
    "friends: #{args.map(&:to_s).join(', ')}"
  end

  private

  def solitaire(*args)
    "solo: #{args.map(&:to_s).join(', ')}"
  end
end

module PlayArgs
  module_function

  def full(x, y = 1, a: 3)
    [x, y, a]
  end

  def full_rest(x, y = 1, *args, a: 2, **kwargs, &block)
    block.call(x, y, *args, a: a, **kwargs)
  end

  def rest(*args)
    args
  end

  def key_rest(**kwargs)
    kwargs
  end

  def both_rest(*args, **kwargs)
    [args, kwargs]
  end
end

class PlayFib
  # Naive fibonacci implementation (we want to test some deep nesting)
  def fib(n)
    raise ArgumentError, 'Must be positive' if n.negative?
    return 1 if n <= 1

    fib(n - 1) + fib(n - 2)
  end
end
