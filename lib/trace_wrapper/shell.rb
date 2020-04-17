# frozen_string_literal: true

class TraceWrapper
  module Shell # :nodoc: all
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

    def colour?
      return @colour unless @colour.nil?
      @output.respond_to?(:isatty) && @output.isatty
    end

    def colour(text, colour)
      return text unless colour?
      "\e[#{COLOURS[colour]}#{text}\e[0m"
    end
  end
end
