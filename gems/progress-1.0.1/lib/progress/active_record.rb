if defined?(ActiveRecord::Base)
  module ActiveRecord
    module BatchesWithProgress
      def find_each_with_progress(options = {})
        Progress.start(name.tableize, count(options)) do
          find_each do |model|
            Progress.step do
              yield model
            end
          end
        end
      end

      def find_in_batches_with_progress(options = {})
        Progress.start(name.tableize, count(options)) do
          find_in_batches do |batch|
            Progress.step batch.length do
              yield batch
            end
          end
        end
      end
    end

    class Base
      extend BatchesWithProgress
    end
  end
end
