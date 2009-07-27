$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'singleton'

class Progress
  include Singleton

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
  #   Progress.start('Test', 10) do
  #     (1..10).to_a.each_slice do |slice|
  #       Progress.step(slice.length)
  #     end
  #   end
  # ==== Enclosed block example
  #   [1, 2, 3].each_with_progress('1 2 3') do |one_of_1_2_3|
  #     10.times_with_progress('10') do |one_of_10|
  #       sleep(0.001)
  #     end
  #   end
  # ==== To output progress as lines (not trying to stay on line)
  #   Progress.start('Test', 1000, :lines => true) do
  #     1000.times{ Progress.step }
  #   end
  def self.start(title, total = 1, options = {})
    levels << new(title, total, levels.length, options)
    print_message
    if block_given?
      result = yield
      stop
      result
    end
  end

  attr_reader :message, :options
  def initialize(title, total, level, options) # :nodoc:
    @title = title + ': %s'
    @total = total
    @level = level
    @options = options
    @current = 0
    start
  end

  def start # :nodoc:
    self.message = '.' * 6
  end

  def step(steps) # :nodoc:
    @current += steps
    self.message = percent
  end

  def stop # :nodoc:
    self.message = percent
  end

protected

  def percent
    '%5.1f%%' % (@current * 100.0 / @total)
  end

  def message=(s)
    formatted = s.ljust(6)[0, 6]
    @message = @title % formatted
  end

  module ClassMethods
    def step(steps = 1)
      levels[-1].step(steps)
      print_message
    end

    def stop
      levels.pop.stop
      @io.puts if levels.empty?
    end

    def io=(io)
      @io = io
    end

  protected

    def print_message
      message = levels.map{ |level| level.message } * ' > '
      @io ||= $stderr
      @io.sync = true
      if @io.tty? && !levels.any?{ |level| level.options[:lines] }
        @io.print message.ljust(@previous_length || 0).gsub(/\d+\.\d+/){ |s| s == '100.0' ? s : "\e[1m#{s}\e[0m" } + "\r"
        @previous_length = message.length
      else
        @io.puts message
      end
    end

    def levels
      @levels ||= []
    end
  end
  extend ClassMethods
end

require 'progress/with_progress'

require 'progress/enumerable'
require 'progress/integer'
