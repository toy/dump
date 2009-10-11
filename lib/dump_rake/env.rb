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
      :backup => %w(BACKUP AUTOBACKUP AUTO_BACKUP),
      :transfer_via => %w(TRANSFER_VIA),
      :show_size => %w(SHOW_SIZE),
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
      {}.tap do |map|
        map[:create] = [:desc, :tags, :assets, :tables]
        map[:restore] = [:like, :tags]
        map[:versions] = [:like, :tags, :summary]
        map[:cleanup] = [:like, :tags, :leave]
        map[:assets] = [:assets]
        map[:transfer] = [:transfer_via] + map[:restore]
        map[:mirror] = [:backup] + map[:create]
        map[:backup] = [:transfer_via] + map[:create]
      end[command] || []
    end

    def self.for_command(command, strings = false)
      variables = variable_names_for_command(command)
      variables.inject({}) do |env, variable|
        value = self[variable]
        env[strings ? dictionary[variable].first : variable] = value if value
        env
      end
    end

    def self.stringify!(hash)
      hash.keys.each do |key|
        hash[dictionary[key] ? dictionary[key].first : key.to_s] = hash.delete(key)
      end
    end

    @explanations = {
      :like => 'filter dumps by full dump name',
      :desc => 'free form description of dump',
      :tags => 'comma separated list of tags',
      :leave => 'number of dumps to leave',
      :summary => 'output info about dump',
      :assets => 'comma or colon separated list of paths or globs to dump',
      :tables => 'comma separated list of tables to dump or if prefixed by "-" — to skip; by default only sessions table is skipped; schema_info and schema_migrations are always included if they are present',
      :backup => 'no autobackup (pass 0 or something starting with "n" or "f")',
      :transfer_via => 'transfer method (rsync, sftp or scp)',
    }.freeze

    def self.explain_variables_for_command(command)
      ".\n" <<
      variable_names_for_command(command).map do |variable_name|
        "  #{dictionary[variable_name].join(', ')} — #{@explanations[variable_name]}\n"
      end.join('')
    end
  end
end
