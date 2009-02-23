require 'pathname'
require 'find'

require 'rake'
require 'rubygems'

$:.push(*Dir[Pathname.new(__FILE__).dirname.join(*%w(.. gems * lib))])
require 'progress'
require 'archive/tar/minitar'

class DumpRake
  def self.versions(version = nil)
    if version
      puts Dump.like(version)
    else
      puts Dump.list
    end
  end

  def self.create(options = {})
    name = Time.now.utc.strftime("%Y%m%d%H%M%S")
    description = clean_description(options[:description])
    name += "-#{description}" unless description.blank?

    path = File.join(RAILS_ROOT, 'dump')
    tmp_name = File.join(path, "#{name}.tmp")
    tgz_name = File.join(path, "#{name}.tgz")

    DumpWriter.create(tmp_name)

    File.rename(tmp_name, tgz_name)
    puts File.basename(tgz_name)
  end

  def self.restore(version)
    dump = if version.nil?
      Dump.last
    elsif (found = Dump.like(version)).length == 1
      found.first
    end
    
    if dump
      # DumpReader.open(dump.path) do |dump|
      #   config = Marshal.load(tar.read('config').first)
      #   tar.read_to_file('schema.rb') do |f|
      #     with_env('SCHEMA', f.path) do
      #       Rake::Task['db:schema:load'].invoke
      #     end
      #   end
      #   Progress.start('Tables', config[:tables].length) do
      #     tar.grep(/\.dump$/) do |entry|
      #       table = entry.full_name[/^(.*)\.dump$/, 1]
      #       table_sql = ActiveRecord::Base.connection.quote_table_name(table)
      #       Progress.start('Loading', config[:tables][table]) do
      #         columns = Marshal.load(entry)
      #         columns_sql = "(#{columns.collect{ |column| ActiveRecord::Base.connection.quote_column_name(column) } * ','})"
      #         until entry.eof?
      #           slice_values = Marshal.load(entry)
      #           slice_values_sqls = slice_values.collect{ |row| "(#{row.collect{ |value| ActiveRecord::Base.connection.quote(value) } * ','})"  }
      #           begin
      #             ActiveRecord::Base.connection.insert("INSERT INTO #{table_sql} #{columns_sql} VALUES #{slice_values_sqls * ','}", 'Load dump')
      #             Progress.step(slice_values_sqls.length)
      #           rescue
      #             slice_values_sqls.each do |slice_values_sql|
      #               ActiveRecord::Base.connection.insert("INSERT INTO #{table_sql} #{columns_sql} VALUES #{slice_values_sql}", 'Load dump')
      #               Progress.step
      #             end
      #           end
      #         end
      #       end
      #       Progress.step
      #     end
      #   end
      #   if config[:assets]
      #     Progress.start('Assets') do
      #       config[:assets].each do |asset|
      #         Dir.glob(File.join(RAILS_ROOT, asset, '*')) do |path|
      #           FileUtils.remove_entry_secure(path)
      #         end
      #       end
      #       tar.read_to_file('assets.tar') do |f|
      #         Archive::Tar::Minitar.unpack(f, RAILS_ROOT)
      #       end
      #       Progress.step
      #     end
      #   end
      # end
    else
      puts "Avaliable versions:"
      versions
    end
  end

protected

  def self.clean_description(description)
    description.to_s.downcase.gsub(/[^a-z0-9]+/, ' ').strip[0, 30].strip.gsub(/ /, '-')
  end
end
