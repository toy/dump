# based on Timeout

class DumpRake
  module ContiniousTimeout
    class TimeoutException < ::Exception; end

    class RestartException < ::Exception; end

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
          rescue RestartException => e
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
