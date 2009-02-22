require 'pathname'
require 'find'

require 'rake'
require 'rubygems'

$:.unshift(*Dir[Pathname.new(__FILE__).dirname.join(*%w(.. gems * lib))])

require 'progress'
require 'archive/tar/minitar'

class DumpRake
  class Dump # :nodoc:
    class Writer # :nodoc:
      def self.create(path)
        Zlib::GzipWriter.open(path) do |gzip|
          Archive::Tar::Minitar::Output.open(gzip) do |stream|
            yield(new(stream.tar))
          end
        end
      end

      def initialize(tar)
        @tar = tar
      end

      def create_file(name)
        Tempfile.open('dumper') do |temp|
          yield(temp)
          temp.open
          @tar.add_file_simple(name, :mode => 0100444, :size => temp.length) do |f|
            f.write(temp.read(4096)) until temp.eof?
          end
        end
      end
    end

    class Reader # :nodoc:
      def self.open(path)
        Zlib::GzipReader.open(path) do |gzip|
          Archive::Tar::Minitar::Input.open(gzip) do |stream|
            yield(new(stream))
          end
        end
      end

      def initialize(tar)
        @tar = tar
      end

      def read(matcher)
        result = []
        entries_like(matcher) do |entry|
          result << entry.read
        end
        result
      end

      def read_to_file(matcher)
        entries_like(matcher) do |entry|
          Tempfile.open('dumper') do |temp|
            temp.write(entry.read(4096)) until entry.eof?
            temp.rewind
            yield(temp)
          end
        end
      end

      def entries_like(matcher)
        @tar.each do |entry|
          if matcher === entry.full_name
            yield(entry)
          end
        end
      end
    end

    def self.list
      Dir.glob(File.join(RAILS_ROOT, 'dump', '*.tgz')).sort.map{ |path| new(path) }
    end

    def initialize(path)
      @path = path
    end

    def path
      @path
    end

    def name
      @name ||= File.basename(path)
    end

    def =~(version)
      name[version]
    end
  end

  def self.versions(version)
    if version
      puts Dump.list.select{ |dump| dump =~ version }.map(&:name)
    else
      puts Dump.list.map(&:name)
    end
  end

  def self.create(options = {})
    ActiveRecord::Base.establish_connection

    time = Time.now.utc.strftime("%Y%m%d%H%M%S")
    path = File.join(RAILS_ROOT, 'dump')
    FileUtils.mkdir_p(path)

    description = options[:description] && options[:description].downcase.gsub(/[^a-z0-9]+/, ' ').lstrip[0, 30].rstrip.gsub(/ /, '-')
    name = description.blank? ? time : "#{time}-#{description}"

    assets = begin
      Rake::Task['assets'].invoke
      ENV['ASSETS'].split(':')
    rescue
      []
    end

    tmp_name = File.join(path, "#{name}.tmp")
    tgz_name = File.join(path, "#{name}.tgz")

    config = {:tables => {}, :assets => assets}
    Dump::Writer.create(tmp_name) do |tar|
      tar.create_file('schema.rb') do |f|
        with_env('SCHEMA', f.path) do
          Rake::Task['db:schema:dump'].invoke
        end
      end
      interesting_tables.each_with_progress('Tables') do |table|
        rows = Progress.start('Getting data') do
          ActiveRecord::Base.connection.select_all("SELECT * FROM `#{table}`")
        end
        unless rows.empty?
          Progress.start('Writing dump', rows.length) do
            tar.create_file("#{table}.dump") do |f|
              columns = rows.first.keys
              Marshal.dump(columns, f)
              rows.each_slice(1000) do |slice|
                slice_values = slice.collect{ |row| row.values_at(*columns) }
                Marshal.dump(slice_values, f)
                Progress.step(slice.length)
              end
            end
          end
          config[:tables][table] = rows.length
        end
      end
      tar.create_file('assets.tar') do |f|
        Progress.start('Assets') do
          Dir.chdir(RAILS_ROOT) do
            Archive::Tar::Minitar.pack(assets, f)
          end
          Progress.step
        end
      end
      tar.create_file('config') do |f|
        Marshal.dump(config, f)
      end
    end

    FileUtils.mv(tmp_name, tgz_name)

    puts Dump.new(tgz_name).name
  end

  def self.restore(version)
    dumps = Dump.list

    dump = if version == :last
      dumps.last
    elsif version == :first
      dumps.first
    elsif (found = dumps.select{ |dump| dump =~ version }).length == 1
      found.first
    end

    if dump
      Dump::Reader.open(dump.path) do |tar|
        config = Marshal.load(tar.read('config').first)
        tar.read_to_file('schema.rb') do |f|
          with_env('SCHEMA', f.path) do
            Rake::Task['db:schema:load'].invoke
          end
        end
        Progress.start('Tables', config[:tables].length) do
          tar.entries_like(/\.dump$/) do |entry|
            table = entry.full_name[/^(.*)\.dump$/, 1]
            table_sql = ActiveRecord::Base.connection.quote_table_name(table)
            Progress.start('Loading', config[:tables][table]) do
              columns = Marshal.load(entry)
              columns_sql = "(#{columns.collect{ |column| ActiveRecord::Base.connection.quote_column_name(column) } * ','})"
              until entry.eof?
                slice_values = Marshal.load(entry)
                slice_values_sqls = slice_values.collect{ |row| "(#{row.collect{ |value| ActiveRecord::Base.connection.quote(value) } * ','})"  }
                begin
                  ActiveRecord::Base.connection.insert("INSERT INTO #{table_sql} #{columns_sql} VALUES #{slice_values_sqls * ','}", 'Load dump')
                  Progress.step(slice_values_sqls.length)
                rescue
                  slice_values_sqls.each do |slice_values_sql|
                    ActiveRecord::Base.connection.insert("INSERT INTO #{table_sql} #{columns_sql} VALUES #{slice_values_sql}", 'Load dump')
                    Progress.step
                  end
                end
              end
            end
            Progress.step
          end
        end
        if config[:assets]
          Progress.start('Assets') do
            config[:assets].each do |asset|
              Dir.glob(File.join(RAILS_ROOT, asset, '*')) do |path|
                FileUtils.remove_entry_secure(path)
              end
            end
            tar.read_to_file('assets.tar') do |f|
              Archive::Tar::Minitar.unpack(f, RAILS_ROOT)
            end
            Progress.step
          end
        end
      end
    else
      puts "Avaliable versions:"
      versions
    end
  end

protected

  def self.interesting_tables
    ActiveRecord::Base.connection.tables - %w(schema_info schema_migrations sessions)
  end

  def self.with_env(key, value)
    old_value, ENV[key] = ENV[key], value
    yield
  ensure
    ENV[key] = old_value
  end
end
