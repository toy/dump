class DumpRake
  module Env
    DICTIONARY = {
      :like => %w(LIKE VER VERSION),
      :desc => %w(DESC DESCRIPTION),
    }

    def self.with_env(hash)
      old = {}
      hash.each do |key, value|
        key = DICTIONARY[key].first if DICTIONARY[key]
        old[key] = ENV[key]
        ENV[key] = value
      end
      begin
        yield
      ensure
        old.each do |key, value|
          ENV[key] = value
        end
      end
    end

    def self.[](key)
      if DICTIONARY[key]
        ENV.values_at(*DICTIONARY[key]).compact.first
      else
        ENV[key]
      end
    end
  end
end
