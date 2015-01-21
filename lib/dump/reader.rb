require 'dump/snapshot'
require 'dump/archive_tar_minitar'
require 'dump/assets'
require 'progress'
require 'rake'
require 'zlib'
require 'tempfile'
require 'dump/reader/summary'
require 'dump/reader/assets'

module Dump
  # Reading dump
  class Reader < Snapshot
    attr_reader :stream, :config

    def self.restore(path)
      new(path).open do |dump|
        dump.silence do
          dump.read_config
          dump.migrate_down
          dump.read_schema

          dump.read_tables
          Assets.new(dump).read
        end
      end
    end

    def self.summary(path, options = {})
      new(path).open do |dump|
        dump.read_config

        sum = Summary.new

        tables = dump.config[:tables]
        sum.header 'Tables'
        sum.data tables.sort.map{ |(table, rows)|
          "#{table}: #{Summary.pluralize(rows, 'row')}"
        }

        assets = dump.config[:assets]
        if assets.present?
          sum.header 'Assets'
          sum.data assets.sort.map{ |entry|
            if entry.is_a?(String)
              entry
            else
              asset, paths = entry
              if paths.is_a?(Hash)
                "#{asset}: #{Summary.pluralize paths[:files], 'file'} (#{Summary.pluralize paths[:total], 'entry'} total)"
              else
                "#{asset}: #{Summary.pluralize paths, 'entry'}"
              end
            end
          }
        end

        if options[:schema]
          sum.header 'Schema'
          sum.data dump.schema.split("\n")
        end

        sum
      end
    end

    def open
      Zlib::GzipReader.open(path) do |gzip|
        Archive::Tar::Minitar.open(gzip, 'r') do |stream|
          @stream = stream
          yield(self)
        end
      end
    end

    def find_entry(matcher)
      stream.each do |entry|
        if entry.full_name.match(matcher)
          # we can not return entry - after exiting stream.each
          # the entry will be invalid and will read from tar start
          return yield(entry)
        end
      end
    end

    def read_entry(matcher)
      find_entry(matcher) do |entry|
        return entry.read
      end
    end

    def read_entry_to_file(matcher)
      find_entry(matcher) do |entry|
        Tempfile.open('dumper') do |temp|
          temp.write(entry.read(4096)) until entry.eof?
          temp.rewind
          yield(temp)
        end
      end
    end

    def read_config
      @config = Marshal.load(read_entry('config'))
    end

    def migrate_down
      case
      when Dump::Env.downcase(:migrate_down) == 'reset'
        Rake::Task['db:drop'].invoke
        Rake::Task['db:create'].invoke
      when !Dump::Env.no?(:migrate_down)
        return unless avaliable_tables.include?('schema_migrations')
        find_entry('schema_migrations.dump') do |entry|
          migrated = table_rows('schema_migrations').map{ |row| row['version'] }

          dump_migrations = []
          Marshal.load(entry) # skip header
          dump_migrations << Marshal.load(entry).first until entry.eof?

          migrate_down = (migrated - dump_migrations)

          unless migrate_down.empty?
            migrate_down.reverse.with_progress('Migrating down') do |version|
              Dump::Env.with_env('VERSION' => version) do
                Rake::Task['db:migrate:down'].tap do |task|
                  begin
                    task.invoke
                  rescue ActiveRecord::IrreversibleMigration
                    $stderr.puts "Irreversible migration: #{version}"
                  end
                  task.reenable
                end
              end
            end
          end
        end
      end
    end

    def restore_schema?
      !Dump::Env.no?(:restore_schema)
    end

    def read_schema
      return unless restore_schema?
      read_entry_to_file('schema.rb') do |f|
        Dump::Env.with_env('SCHEMA' => f.path) do
          Rake::Task['db:schema:load'].invoke
        end
        Rake::Task['db:schema:dump'].invoke
      end
    end

    def schema
      read_entry('schema.rb')
    end

    def read_tables
      return if Dump::Env[:restore_tables] && Dump::Env[:restore_tables].empty?
      verify_connection
      config[:tables].with_progress('Tables') do |table, rows|
        if (restore_schema? && schema_tables.include?(table)) || Dump::Env.filter(:restore_tables).pass?(table)
          read_table(table, rows)
        end
      end
    end

    def rebuild_indexes?
      Dump::Env.yes?(:rebuild_indexes)
    end

    def read_table(table, rows_count)
      find_entry("#{table}.dump") do |entry|
        table_sql = quote_table_name(table)
        clear_table(table_sql)

        columns_sql = columns_insert_sql(Marshal.load(entry))
        if rebuild_indexes?
          with_disabled_indexes table do
            bulk_insert_into_table(table, rows_count, entry, table_sql, columns_sql)
          end
        else
          bulk_insert_into_table(table, rows_count, entry, table_sql, columns_sql)
        end
        fix_sequence!(table)
      end
    end

    def bulk_insert_into_table(table, rows_count, entry, table_sql, columns_sql)
      Progress.start(table, rows_count) do
        until entry.eof?
          rows_sql = []
          1000.times do
            rows_sql << values_insert_sql(Marshal.load(entry)) unless entry.eof?
          end

          begin
            insert_into_table(table_sql, columns_sql, rows_sql)
            Progress.step(rows_sql.length)
          rescue
            rows_sql.each do |row_sql|
              insert_into_table(table_sql, columns_sql, row_sql)
              Progress.step
            end
          end
        end
      end
    end
  end
end
