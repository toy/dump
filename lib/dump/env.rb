# encoding: UTF-8

require 'dump/env/filter'

module Dump
  # Working with environment variables
  module Env
    DICTIONARY = {
      :desc => %w[DESC DESCRIPTION],
      :like => %w[LIKE VER VERSION],
      :tags => %w[TAGS TAG],
      :leave => %w[LEAVE],
      :summary => %w[SUMMARY],
      :assets => %w[ASSETS],
      :tables => %w[TABLES],
      :backup => %w[BACKUP AUTOBACKUP AUTO_BACKUP],
      :transfer_via => %w[TRANSFER_VIA],
      :migrate_down => %w[MIGRATE_DOWN],
      :restore_schema => %w[RESTORE_SCHEMA],
      :restore_tables => %w[RESTORE_TABLES],
      :restore_assets => %w[RESTORE_ASSETS],
      :show_size => %w[SHOW_SIZE], # internal
    }.freeze unless defined? DICTIONARY

    EXPLANATIONS = {
      :desc => 'free form description of dump',
      :like => 'filter dumps by full dump name',
      :tags => 'comma separated list of tags',
      :leave => 'number of dumps to leave',
      :summary => 'output info about dump: "1", "true" or "yes" for basic info, "2" or "schema" to display schema as well',
      :assets => 'comma or colon separated list of paths or globs to dump',
      :tables => 'comma separated list of tables to dump or if prefixed by "-" — to skip; by default only sessions table is skipped; schema_info and schema_migrations are always included if they are present',
      :backup => 'no autobackup if you pass "0", "no" or "false"',
      :transfer_via => 'transfer method (rsync, sftp or scp)',
      :migrate_down => 'don\'t run down for migrations not present in dump if you pass "0", "no" or "false"; pass "reset" to recreate (drop and create) db',
      :restore_schema => 'don\'t read/change schema if you pass "0", "no" or "false" (useful to just restore data for table; note that schema info tables are also not restored)',
      :restore_tables => 'works as TABLES, but for restoring',
      :restore_assets => 'works as ASSETS, but for restoring',
    }.freeze unless defined? EXPLANATIONS

    class << self
      def with_env(hash)
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

      def with_clean_env(hash = {}, &block)
        empty_env = {}
        DICTIONARY.keys.each{ |key| empty_env[key] = nil }
        with_env(empty_env.merge(hash), &block)
      end

      def [](key)
        if DICTIONARY[key]
          ENV.values_at(*DICTIONARY[key]).compact.first
        else
          ENV[key]
        end
      end

      def filter(key, splitter = nil)
        @filters ||= Hash.new{ |h, k| h[k] = Filter.new(*k) }
        @filters[[self[key], splitter]]
      end

      def yes?(key)
        %w[1 y t].include?(first_char(key))
      end

      def no?(key)
        %w[0 n f].include?(first_char(key))
      end

      def downcase(key)
        self[key].to_s.downcase.strip
      end

      def variable_names_for_command(command)
        m = {
          :select => [:like, :tags],
          :assets => [:assets],
          :restore_options => [:migrate_down, :restore_schema, :restore_tables, :restore_assets],
          :transfer_options => [:transfer_via],
        }

        m[:versions] = m[:select] | [:summary]
        m[:create] = [:desc, :tags, :tables] | m[:assets]
        m[:restore] = m[:select] | m[:restore_options]
        m[:cleanup] = m[:select] | [:leave]

        m[:transfer] = m[:select] | m[:transfer_options]

        m[:mirror] = [:backup] | m[:create] | m[:transfer_options] | m[:restore_options]
        m[:backup] = m[:create] | [:transfer_via]
        m[:backup_restore] = m[:transfer] | m[:restore_options]

        m[command] || []
      end

      def for_command(command, strings = false)
        env = {}
        variable_names_for_command(command).each do |variable|
          if (value = self[variable])
            env[strings ? DICTIONARY[variable].first : variable] = value
          end
        end
        env
      end

      def stringify!(hash)
        hash.keys.each do |key|
          hash[DICTIONARY[key] ? DICTIONARY[key].first : key.to_s] = hash.delete(key)
        end
      end

      def explain_variables_for_command(command)
        ".\n" <<
          variable_names_for_command(command).map do |variable_name|
            "  #{DICTIONARY[variable_name].join(', ')} — #{EXPLANATIONS[variable_name]}\n"
          end.join('')
      end

    private

      def first_char(key)
        downcase(key)[0, 1]
      end
    end
  end
end
