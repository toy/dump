$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'singleton'

class Progress
  include Singleton

  module InstanceMethods # :nodoc:
    attr_accessor :title, :current, :total
    def initialize(title, total)
      total = Float(total)
      @title, @current, @total = title, 0.0, total == 0.0 ? 1.0 : total
    end

    def step_if_blank
      self.current = 1.0 if current == 0.0 && total == 1.0
    end

    def to_f(inner)
      (current + (inner < 1.0 ? inner : 1.0)) / total
    end
  end
  include InstanceMethods

  class << self
    # start progress indication
    # ==== Procedural example
    #   Progress.start('Test', 1000)
    #   1000.times{ Progress.step }
    #   Progress.stop
    # ==== Block example
    #   Progress.start('Test', 1000) do
    #     1000.times{ Progress.step }
    #   end
    # ==== Step must not always be one
    #   symbols = []
    #   Progress.start('Input 100 symbols', 100) do
    #     while symbols.length < 100
    #       input = gets.scan(/\S/)
    #       symbols += input
    #       Progress.step input.length
    #     end
    #   end
    # ==== Enclosed block example
    #   [1, 2, 3].each_with_progress('1 2 3') do |one_of_1_2_3|
    #     10.times_with_progress('10') do |one_of_10|
    #       sleep(0.001)
    #     end
    #   end
    # ==== To output progress as lines (not trying to stay on line)
    #   Progress.lines = true
    # ==== To force highlight
    #   Progress.highlight = true
    def start(title, total = 1)
      levels << new(title, total)
      print_message
      if block_given?
        result = yield
        stop
        result
      end
    end

    def step(steps = 1)
      levels.last.current += Float(steps)
      print_message
    end

    def set(value)
      levels.last.current = Float(value)
      print_message
    end

    def stop
      print_message if levels.last.step_if_blank
      levels.pop
      io.puts if levels.empty?
    end

    attr_writer :io, :lines, :highlight # :nodoc:

  private

    def levels
      @levels ||= []
    end

    def io
      @io ||= $stderr
      @io.sync = true
      @io
    end

    def io_tty?
      io.tty? || ENV['PROGRESS_TTY']
    end

    def lines?
      @lines.nil? ? !io_tty? : @lines
    end

    def highlight?
      @highlight.nil? ? io_tty? : @highlight
    end

    def print_message
      messages = []
      inner = 0
      levels.reverse.each do |l|
        current = l.to_f(inner)
        messages << "#{l.title}: #{(current == 0 ? '......' : '%5.1f%%' % (current * 100.0))[0, 6]}"
        inner = current
      end
      message = messages.reverse * ' > '

      unless lines?
        previous_length = @previous_length || 0
        @previous_length = message.length
        message = message.ljust(previous_length, ' ') + "\r"
      end

      message.gsub!(/\d+\.\d+/){ |s| s == '100.0' ? s : "\e[1m#{s}\e[0m" } if highlight?

      lines? ? io.puts(message) : io.print(message)
    end
  end
end

require 'progress/with_progress'

require 'progress/enumerable'
require 'progress/integer'
