require 'dump/snapshot'
require 'dump/archive_tar_minitar'
require 'dump/assets'
require 'progress'
require 'rake'
require 'zlib'
require 'tempfile'

module Dump
  # Creating dump
  class Writer < Snapshot
    attr_reader :stream, :config

    def self.create(path)
      new(path).open do |dump|
        dump.silence do
          dump.write_schema

          dump.write_tables
          dump.write_assets

          dump.write_config
        end
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
        stream.tar.add_file_simple(name, :mode => 0o100444, :size => temp.length) do |f|
          f.write(temp.read(4096)) until temp.eof?
        end
      end
    end

    def write_schema
      create_file('schema.rb') do |f|
        Dump::Env.with_env('SCHEMA' => f.path) do
          Rake::Task['db:schema:dump'].invoke
        end
      end
    end

    def write_tables
      verify_connection
      tables_to_dump.with_progress('Tables') do |table|
        write_table(table)
      end
    end

    def write_table(table)
      row_count = table_row_count(table)
      config[:tables][table] = row_count
      Progress.start(table, 1 + row_count) do
        create_file("#{table}.dump") do |f|
          columns = table_columns(table)
          column_names = columns.map(&:name).sort
          columns_by_name = columns.index_by(&:name)

          Marshal.dump(column_names, f)
          Progress.step

          type_cast = if columns.first.respond_to?(:type_cast_from_database)
            proc do |column_name, value|
              columns_by_name[column_name].type_cast_from_database(value)
            end
          else
            proc do |column_name, value|
              columns_by_name[column_name].type_cast(value)
            end
          end

          each_table_row(table, row_count) do |row|
            values = column_names.map do |column_name|
              type_cast.call(column_name, row[column_name])
            end
            Marshal.dump(values, f)
            Progress.step
          end
        end
      end
    end

    def write_assets
      assets = assets_to_dump
      return if assets.blank?

      config[:assets] = {}
      Dir.chdir(Dump.rails_root) do
        assets = Dir[*assets].uniq
        assets.with_progress('Assets') do |asset|
          paths = Dir[File.join(asset, '**/*')]
          files = paths.select{ |path| File.file?(path) }
          config[:assets][asset] = {:total => paths.length, :files => files.length}
          assets_root_link do |_tmpdir, prefix|
            paths.with_progress(asset) do |entry|
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

    def write_config
      create_file('config') do |f|
        Marshal.dump(config, f)
      end
    end

    def assets_to_dump
      Rake::Task['assets'].invoke
      Dump::Env[:assets].split(Dump::Assets::SPLITTER)
    rescue
      []
    end
  end
end
