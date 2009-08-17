class DumpRake
  module Env
    @dictionary = {
      :like => %w(LIKE VER VERSION),
      :desc => %w(DESC DESCRIPTION),
      :tags => %w(TAGS TAG),
      :leave => %w(LEAVE),
      :summary => %w(SUMMARY),
      :assets => %w(ASSETS),
      :tables => %w(TABLES),
    }.freeze
    def self.dictionary
      @dictionary
    end

    def self.with_env(hash)
      old = {}
      hash.each do |key, value|
        key = dictionary[key].first if dictionary[key]
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

    def self.with_clean_env(hash = {}, &block)
      empty_env = {}
      dictionary.keys.each{ |key| empty_env[key] = nil }
      with_env(empty_env.merge(hash), &block)
    end

    def self.[](key)
      if dictionary[key]
        ENV.values_at(*dictionary[key]).compact.first
      else
        ENV[key]
      end
    end

    def self.variable_names_for_command(command)
      case command
      when :create
        [:desc, :tags, :assets, :tables]
      when :restore
        [:like, :tags]
      when :versions
        [:like, :tags, :summary]
      when :cleanup
        [:like, :tags, :leave]
      else
        []
      end
    end

    def self.for_command(command, strings = false)
      variables = variable_names_for_command(command)
      variables.inject({}) do |env, variable|
        value = self[variable]
        env[strings ? dictionary[variable].first : variable] = value if value
        env
      end
    end
  end
end
