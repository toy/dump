# based on Timeout

module Dump
  # Timeout if does not finish or defer in requested time
  module ContiniousTimeout
    class TimeoutException < ::Exception; end

    class RestartException < ::Exception; end

    # Object with defer method
    class Deferer
      def initialize(thread)
        @thread = thread
      end

      def defer
        @thread.raise RestartException.new
      end
    end

    def self.timeout(sec)
      x = Thread.current
      y = Thread.start do
        1.times do
          begin
            sleep sec
          rescue RestartException
            retry
          end
        end
        x.raise TimeoutException, 'execution expired' if x.alive?
      end
      yield Deferer.new(y)
    ensure
      y.kill if y && y.alive?
    end
  end
end
