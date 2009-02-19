$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'singleton'

class Progress
  VERSION = '0.0.6'

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
  def self.start(name, total = 1)
    levels << new(name, total, levels.length)
    print_message
    if block_given?
      result = yield
      stop
      result
    end
  end

  def self.step(steps = 1)
    levels[-1].step(steps)
    print_message
  end

  def self.stop
    levels.pop.stop
    @io.puts if levels.empty?
  end

  def self.io=(io) # :nodoc:
    @io = io
  end

  def initialize(name, total, level) # :nodoc:
    @name = name + ': %s'
    @total = total
    @level = level
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

  def message # :nodoc:
    @message
  end

protected

  def self.print_message
    message = levels.map{ |level| level.message } * ' > '
    @io ||= $stderr
    @io.sync = true
    @io.print "\r" + message.ljust(@previous_length || 0).gsub(/\d+\.\d+/){ |s| s == '100.0' ? s : "\e[1m#{s}\e[0m" }
    @previous_length = message.length
  end

  def self.levels
    @levels ||= []
  end

  def percent
    '%5.1f%%' % (@current * 100.0 / @total)
  end

  def message=(s)
    formatted = s.ljust(6)[0, 6]
    @message = @name % formatted
  end
end

require 'progress/enumerable'
require 'progress/integer'
