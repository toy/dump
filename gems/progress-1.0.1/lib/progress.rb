require 'singleton'

class Progress
  include Singleton

  module InstanceMethods # :nodoc:
    attr_accessor :title, :current, :total
    attr_reader :current_step
    def initialize(title, total)
      if title.is_a?(Numeric) && total.nil?
        title, total = nil, title
      elsif total.nil?
        total = 1
      end
      @title = title
      @current = 0.0
      @total = total == 0.0 ? 1.0 : Float(total)
    end

    def step_if_blank
      if current == 0.0 && total == 1.0
        self.current = 1.0
      end
    end

    def to_f(inner)
      inner = [inner, 1.0].min
      if current_step
        inner *= current_step
      end
      (current + inner) / total
    end

    def step(steps)
      @current_step = steps
      yield
    ensure
      @current_step = nil
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
    def start(title = nil, total = nil)
      if levels.empty?
        @started_at = Time.now
        @eta = nil
      end
      levels << new(title, total)
      print_message(true)
      if block_given?
        begin
          yield
        ensure
          stop
        end
      end
    end

    def step(num = 1, den = 1, &block)
      if levels.last
        set(levels.last.current + Float(num) / den, &block)
      elsif block
        block.call
      end
    end

    def set(value, &block)
      if levels.last
        ret = if block
          levels.last.step(value - levels.last.current, &block)
        end
        if levels.last
          levels.last.current = Float(value)
        end
        print_message
        ret
      elsif block
        block.call
      end
    end

    def stop
      if levels.last
        if levels.last.step_if_blank || levels.length == 1
          print_message(true)
          set_title(nil)
        end
        levels.pop
        if levels.empty?
          io.puts
        end
      end
    end

    attr_writer :lines, :highlight # :nodoc:

  private

    def levels
      @levels ||= []
    end

    def io
      unless @io
        @io = $stderr
        @io.sync = true
      end
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

    def time_to_print?
      if !@previous || @previous < Time.now - 0.3
        @previous = Time.now
        true
      end
    end

    def eta(completed)
      now = Time.now
      if now > @started_at && completed > 0
        current_eta = @started_at + (now - @started_at) / completed
        @eta = @eta ? @eta + (current_eta - @eta) * (1 + completed) * 0.5 : current_eta
        seconds = @eta - now
        if seconds > 0
          left = case seconds
          when 0...60
            '%.0fs' % seconds
          when 60...3600
            '%.1fm' % (seconds / 60)
          when 3600...86400
            '%.1fh' % (seconds / 3600)
          else
            '%.1fd' % (seconds / 86400)
          end
          eta_string = " (ETA: #{left})"
        end
      end
    end

    def set_title(title)
      if io_tty?
        io.print("\e]0;#{title}\a")
      end
    end

    def print_message(force = false)
      if force || time_to_print?
        inner = 0
        parts = []
        parts_cl = []
        levels.reverse.each do |l|
          current = l.to_f(inner)
          value = current == 0 ? '......' : "#{'%5.1f' % (current * 100.0)}%"
          inner = current

          title = l.title ? "#{l.title}: " : ''
          highlighted = "\e[1m#{value}\e[0m"
          if !highlight? || value == '100.0%'
            parts << "#{title}#{value}"
          else
            parts << "#{title}#{highlighted}"
          end
          parts_cl << "#{title}#{value}"
        end

        eta_string = eta(inner)
        message = "#{parts.reverse * ' > '}#{eta_string}"
        message_cl = "#{parts_cl.reverse * ' > '}#{eta_string}"

        unless lines?
          previous_length = @previous_length || 0
          @previous_length = message_cl.length
          message = "#{message}#{' ' * [previous_length - message_cl.length, 0].max}\r"
        end

        lines? ? io.puts(message) : io.print(message)
        set_title(message_cl)
      end
    end
  end
end

require 'progress/enumerable'
require 'progress/integer'
require 'progress/kernel'
require 'progress/active_record'
