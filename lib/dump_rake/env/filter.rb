# encoding: utf-8
class DumpRake
  module Env
    class Filter
      attr_reader :invert, :values, :transparent
      def initialize(s, splitter = nil)
        if s
          s = s.dup
          @invert = !!s.sub!(/^-/, '')
          @values = s.split(splitter || ',').map(&:strip).map(&:downcase).uniq.select(&:present?)
        else
          @transparent = true
        end
      end

      def pass?(value)
        transparent || (invert ^ values.include?(value.to_s.downcase))
      end

      def custom_pass?(&block)
        transparent || (invert ^ values.any?(&block))
      end
    end
  end
end
