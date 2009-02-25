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
        with_env('SCHEMA', f.path) do
          Rake::Task['db:schema:load'].invoke
        end
      end
    end

    def read_tables
      establish_connection
      config[:tables].each_with_progress('Tables') do |table, rows|
        read_table(table, rows)
      end
    end

    def read_table(table, rows_count)
      if entry = find_entry("#{table}.dump")
        columns = Marshal.load(entry)

        table_sql = quote_table_name(table)
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
        config[:assets].each do |asset|
          path = File.expand_path(asset, RAILS_ROOT)
          if File.dirname(path)[0, RAILS_ROOT.length] == RAILS_ROOT # asset must be in RAILS_ROOT
            Dir.glob(File.join(path, '*')) do |path|
              FileUtils.remove_entry_secure(path)
            end
          end
        end

        Progress.start('Assets') do
          find_entry('assets.tar') do |entry|
            def entry.rewind
              # rewind will fail - it must go to center of gzip
              # also we don't need it - this is last step in dump restore
            end
            Archive::Tar::Minitar.unpack(entry, RAILS_ROOT)
          end
          Progress.step
        end
      end
    end

  protected

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
