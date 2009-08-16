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
      Tempfile.open('dumper') do |temp|
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
        config[:assets] = []
        create_file('assets.tar') do |f|
          Dir.chdir(RAILS_ROOT) do
            Archive::Tar::Minitar.open(f, 'w') do |outp|
              Dir[*assets].each_with_progress('Assets') do |asset|
                config[:assets] << asset
                Dir[File.join(asset, '**', '*')].each_with_progress(asset) do |entry|
                  begin
                    Archive::Tar::Minitar.pack_file(entry, outp)
                  rescue => e
                    STDERR.puts "Skipped asset due to error #{e}"
                  end
                end
              end
            end
          end
          Progress.start("Putting assets into dump", 1){}
        end
      end
    end

    def write_config
      create_file('config') do |f|
        Marshal.dump(config, f)
      end
    end

    def tables_to_dump
      ActiveRecord::Base.connection.tables - %w(sessions)
    end

    def table_rows(table)
      ActiveRecord::Base.connection.select_all("SELECT * FROM #{quote_table_name(table)}")
    end

    def assets_to_dump
      begin
        Rake::Task['assets'].invoke
        ENV['ASSETS'].split(':')
      rescue
        []
      end
    end
  end
end
