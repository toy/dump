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
      rows = table_rows(table)
      unless rows.blank?
        config[:tables][table] = rows.length
        Progress.start('Writing dump', 1 + rows.length) do
          create_file("#{table}.dump") do |f|
            column_names = rows.first.keys.sort
            columns_by_name = ActiveRecord::Base.connection.columns(table).index_by(&:name)
            Marshal.dump(column_names, f)
            Progress.step
            rows.each do |row|
              values = column_names.map do |column|
                columns_by_name[column].type_cast(row[column])
              end
              Marshal.dump(values, f)
              Progress.step
            end
          end
        end
      end
    end

    def write_assets
      assets = assets_to_dump
      unless assets.blank?
        config[:assets] = {}
        Dir.chdir(RAILS_ROOT) do
          assets = Dir[*assets].uniq
          Progress.start('Assets', assets.length * 100) do
            create_file('assets.tar') do |assets_tar|
              Archive::Tar::Minitar.open(assets_tar, 'w') do |outp|
                assets.each do |asset|
                  paths = Dir[File.join(asset, '**', '*')]
                  files = paths.select{ |path| File.file?(path) }
                  config[:assets][asset] = {:total => paths.length, :files => files.length}
                  paths.each_with_progress(asset) do |entry|
                    begin
                      Archive::Tar::Minitar.pack_file(entry, outp)
                    rescue => e
                      $stderr.puts "Skipped asset due to error #{e}"
                    end
                  end
                  Progress.step 99
                end
              end
              Progress.start("Putting assets into dump", 1){}
            end
            Progress.step assets.length
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

    def table_rows(table)
      ActiveRecord::Base.connection.select_all("SELECT * FROM #{quote_table_name(table)}")
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
