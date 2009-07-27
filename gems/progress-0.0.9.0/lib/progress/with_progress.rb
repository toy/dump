require 'delegate'

class Progress
  class WithProgress
    attr_reader :object, :title
    def initialize(object, title)
      @object = Progress::Enhancer.new(object)
      @title = title
    end

    def with_progress(title)
      self
    end

    def method_missing(method, *args, &block)
      Progress.start(title, object.length) do
        object.send(method, *args, &block)
      end
    end
  end

  class Enhancer < SimpleDelegator
    include Enumerable
    def each(*args, &block)
      __getobj__.each(*args) do |*yielded|
        block.call(*yielded)
        Progress.step
      end
    end

    def length
      if __getobj__.respond_to?(:length) && !__getobj__.is_a?(String)
        __getobj__.length
      elsif __getobj__.respond_to?(:to_a)
        __getobj__.to_a.length
      else
        __getobj__.inject(0){ |length, obj| length + 1 }
      end
    end
  end
end
