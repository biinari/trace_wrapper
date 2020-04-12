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
end

class PlayFib
  # Naive fibonacci implementation (we want to test some deep nesting)
  def fib(n)
    raise ArgumentError, 'Must be positive' if n.negative?
    return 1 if n <= 1

    fib(n - 1) + fib(n - 2)
  end
end
