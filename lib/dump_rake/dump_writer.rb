class DumpRake
  class DumpWriter < Dump
    attr_reader :stream, :config

    def self.create(path)
      new(path).open do |dump|
        dump.write_schema

        dump.write_tables
        dump.write_assets

        dump.write_config
      end
    end

    def open
      Pathname.new(path).dirname.mkpath
      Zlib::GzipWriter.open(path) do |gzip|
        gzip.mtime = Time.utc(2000)
        lock do
          Archive::Tar::Minitar.open(gzip, 'w') do |stream|
            @stream = stream
            @config = {:tables => {}}
            yield(self)
          end
        end
      end
    end

    def create_file(name)
      Tempfile.open('dump') do |temp|
        yield(temp)
        temp.open
        stream.tar.add_file_simple(name, :mode => 0100444, :size => temp.length) do |f|
          f.write(temp.read(4096)) until temp.eof?
        end
      end
    end

    def write_schema
      create_file('schema.rb') do |f|
        DumpRake::Env.with_env('SCHEMA' => f.path) do
          Rake::Task['db:schema:dump'].invoke
        end
      end
    end

    def write_tables
      verify_connection
      tables_to_dump.each_with_progress('Tables') do |table|
        write_table(table)
      end
    end

    def write_table(table)
      row_count = table_row_count(table)
      config[:tables][table] = row_count
      Progress.start('Writing dump', 1 + row_count) do
        create_file("#{table}.dump") do |f|
          columns = table_columns(table)
          column_names = columns.map(&:name).sort
          columns_by_name = columns.index_by(&:name)

          Marshal.dump(column_names, f)
          Progress.step

          written_rows = 0
          each_table_row(table, row_count) do |row|
            values = column_names.map do |column|
              columns_by_name[column].type_cast(row[column])
            end
            Marshal.dump(values, f)
            Progress.step
            written_rows += 1
          end
        end
      end
    end

    def write_assets
      assets = assets_to_dump
      if assets.present?
        config[:assets] = {}
        Dir.chdir(RAILS_ROOT) do
          assets = Dir[*assets].uniq
          assets.with_progress('Assets').each do |asset|
            paths = Dir[File.join(asset, '**', '*')]
            files = paths.select{ |path| File.file?(path) }
            config[:assets][asset] = {:total => paths.length, :files => files.length}
            assets_root_link do |tmpdir, prefix|
              paths.each_with_progress(asset) do |entry|
                begin
                  Archive::Tar::Minitar.pack_file(File.join(prefix, entry), stream)
                rescue => e
                  $stderr.puts "Skipped asset due to error #{e}"
                end
              end
            end
          end
        end
      end
    end

    def write_config
      create_file('config') do |f|
        Marshal.dump(config, f)
      end
    end

    def tables_to_dump
      avaliable_tables = ActiveRecord::Base.connection.tables
      if DumpRake::Env[:tables]
        env_tables = DumpRake::Env[:tables].dup
        prefix = env_tables.slice!(/^\-/)
        candidates = env_tables.split(',').map(&:strip).map(&:downcase).uniq.reject(&:blank?)
        if prefix
          avaliable_tables - (candidates - schema_tables)
        else
          avaliable_tables & (candidates | schema_tables)
        end
      else
        avaliable_tables - %w(sessions)
      end
    end

    def table_row_count(table)
      ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{quote_table_name(table)}").to_i
    end

    def table_chunk_size(table)
      expected_row_size = ActiveRecord::Base.connection.columns(table).map do |column|
        case column.type
        when :text
          Math.sqrt(column.limit || 2_147_483_647)
        when :string
          Math.sqrt(column.limit || 255)
        else
          column.limit || 10
        end
      end.sum
      [[(10_000_000 / expected_row_size).round, 100].max, 3_000].min
    end

    def table_columns(table)
      ActiveRecord::Base.connection.columns(table)
    end

    def table_has_primary_column?(table)
      # bad test for primary column, but primary for primary column was nil
      table_columns(table).any?{ |column| column.name == 'id' && column.type == :integer }
    end
    def table_primary_key(table)
      'id'
    end

    def each_table_row(table, row_count, &block)
      if table_has_primary_column?(table) && row_count > (chunk_size = table_chunk_size(table))
        # adapted from ActiveRecord::Batches
        primary_key = table_primary_key(table)
        quoted_primary_key = "#{quote_table_name(table)}.#{quote_column_name(table_primary_key(table))}"
        select_where_primary_key = [
          "SELECT * FROM #{quote_table_name(table)}",
          "WHERE #{quoted_primary_key} %s",
          "ORDER BY #{quoted_primary_key} ASC",
          "LIMIT #{chunk_size}"
        ].join(' ')
        rows = select_all_by_sql(select_where_primary_key % '>= 0')
        until rows.blank?
          rows.each(&block)
          rows = select_all_by_sql(select_where_primary_key % "> #{rows.last[primary_key].to_i}")
        end
      else
        select_all_by_sql("SELECT * FROM #{quote_table_name(table)}").each(&block)
      end
    end

    def select_all_by_sql(sql)
      ActiveRecord::Base.connection.select_all(sql)
    end

    def assets_to_dump
      begin
        Rake::Task['assets'].invoke
        DumpRake::Env[:assets].split(/[:,]/)
      rescue
        []
      end
    end
  end
end
