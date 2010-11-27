# encoding: utf-8
class DumpRake
  module Env
    class Filter
      attr_reader :invert, :values
      def initialize(s)
        s = s.dup
        @invert = !!s.sub!(/^-/, '')
        @values = s.split(',').map(&:strip).map(&:downcase).uniq.select(&:present?)
      end

      def pass?(value)
        invert ^ values.include?(value.to_s.downcase)
      end

      def filter(values)
        values.select do |value|
          pass?(value) || (block_given? && yield(value))
        end
      end
    end
  end
end
