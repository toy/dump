class DumpRake
  class DumpReader < Dump
    attr_reader :stream, :config

    def self.restore(path)
      new(path).open do |dump|
        dump.read_config
        dump.read_schema

        dump.read_tables
        dump.read_assets
      end
    end

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
        sum.header 'Assets'
        sum.data assets.sort.map{ |entry|
          if String === entry
            entry
          else
            asset, paths = entry
            if Hash === paths
              "#{asset}: #{Summary.pluralize paths[:files], 'file'} (#{Summary.pluralize paths[:total], 'entry'} total)"
            else
              "#{asset}: #{Summary.pluralize paths, 'entry'}"
            end
          end
        }

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
        if matcher === entry.full_name
          # we can not return entry - after exiting stream.each the entry will be invalid and will read from tar start
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

    def read_schema
      read_entry_to_file('schema.rb') do |f|
        DumpRake::Env.with_env('SCHEMA' => f.path) do
          Rake::Task['db:schema:load'].invoke
        end
        Rake::Task['db:schema:dump'].invoke
      end
    end

    def schema
      read_entry('schema.rb')
    end

    def read_tables
      verify_connection
      config[:tables].each_with_progress('Tables') do |table, rows|
        read_table(table, rows)
      end
    end

    def read_table(table, rows_count)
      find_entry("#{table}.dump") do |entry|
        table_sql = quote_table_name(table)
        clear_table(table_sql) if schema_tables.include?(table)

        columns = Marshal.load(entry)
        columns_sql = columns_insert_sql(columns)
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

    def read_assets
      unless config[:assets].blank?
        assets = config[:assets]
        if Hash === assets
          assets_count = assets.values.sum{ |value| Hash === value ? value[:total] : value }
          assets_paths = assets.keys
        else
          assets_count, assets_paths = nil, assets
        end

        DumpRake::Env.with_env('ASSETS' => assets_paths.join(':')) do
          Rake::Task['assets:delete'].invoke
        end

        Progress.start('Assets', assets_count || 1) do
          find_entry('assets.tar') do |assets_tar|
            def assets_tar.rewind
              # rewind will fail - it must go to center of gzip
              # also we don't need it - this is last step in dump restore
            end
            Archive::Tar::Minitar.open(assets_tar) do |inp|
              inp.each do |entry|
                inp.extract_entry(RAILS_ROOT, entry)
                Progress.step if assets_count
              end
            end
          end
          Progress.step unless assets_count
        end
      end
    end

  protected

    def clear_table(table_sql)
      ActiveRecord::Base.connection.delete("DELETE FROM #{table_sql}", 'Clearing table')
    end

    def quote_column_name(column)
      ActiveRecord::Base.connection.quote_column_name(column)
    end

    def quote_value(value)
      ActiveRecord::Base.connection.quote(value)
    end

    def join_for_sql(quoted)
      "(#{quoted.join(',')})"
    end

    def insert_into_table(table_sql, columns_sql, values_sql)
      values_sql = values_sql.join(',') if values_sql.is_a?(Array)
      ActiveRecord::Base.connection.insert("INSERT INTO #{table_sql} #{columns_sql} VALUES #{values_sql}", 'Loading dump')
    end

    def columns_insert_sql(columns)
      join_for_sql(columns.map{ |column| quote_column_name(column) })
    end

    def values_insert_sql(values)
      join_for_sql(values.map{ |column| quote_value(column) })
    end
  end
end
