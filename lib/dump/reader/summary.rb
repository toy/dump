module Dump
  class Reader < Snapshot
    # Helper class for building summary of dump
    class Summary
      attr_reader :text
      alias_method :to_s, :text
      def initialize
        @text = ''
      end

      def header(header)
        @text << "  #{header}:\n"
      end

      def data(entries)
        entries.each do |entry|
          @text << "    #{entry}\n"
        end
      end

      # from ActionView::Helpers::TextHelper
      def self.pluralize(count, singular)
        "#{count} #{count == 1 ? singular : singular.pluralize}"
      end
    end
  end
end
