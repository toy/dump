# encoding: utf-8
class DumpRake
  module Env
    class Filter
      attr_reader :invert, :values, :transparent
      def initialize(s)
        if s
          s = s.dup
          @invert = !!s.sub!(/^-/, '')
          @values = s.split(',').map(&:strip).map(&:downcase).uniq.select(&:present?)
        else
          @transparent = true
        end
      end

      def pass?(value)
        transparent || (invert ^ values.include?(value.to_s.downcase))
      end
    end
  end
end
