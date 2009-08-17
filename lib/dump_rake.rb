require 'rubygems'

require 'pathname'
require 'find'
require 'fileutils'
require 'zlib'

require 'rake'

def require_gem_or_unpacked_gem(name, version = nil)
  unpacked_gems_path = Pathname(__FILE__).dirname.parent + 'gems'

  begin
    gem name, version if version
    require name
  rescue Gem::LoadError, MissingSourceFile
    $: << Pathname.glob(unpacked_gems_path + "#{name.gsub('/', '-')}*").last + 'lib'
    require name
  end
end

require_gem_or_unpacked_gem 'archive/tar/minitar'
require_gem_or_unpacked_gem 'progress', '>= 0.0.6'

class DumpRake
  def self.versions(options = {})
    Dump.list(options).each do |dump|
      puts dump
      if options[:summary]
        begin
          if %w(full 2).include?((options[:summary] || '').downcase)
            puts DumpReader.summary(dump.path, :schema => true)
          else
            puts DumpReader.summary(dump.path)
          end
          puts
        rescue => e
          $stderr.puts "Error reading dump: #{e}"
          $stderr.puts
        end
      end
    end
  end

  def self.create(options = {})
    dump = Dump.new(options.merge(:dir => File.join(RAILS_ROOT, 'dump')))

    DumpWriter.create(dump.tmp_path)

    File.rename(dump.tmp_path, dump.tgz_path)
    puts File.basename(dump.tgz_path)
  end

  def self.restore(options = {})
    dump = Dump.list(options).last

    if dump
      DumpReader.restore(dump.path)
    else
      $stderr.puts "Avaliable versions:"
      $stderr.puts Dump.list
    end
  end

  def self.cleanup(options = {})
    to_delete = []

    all_dumps = Dump.list(options.merge(:all => true))
    to_delete.concat(all_dumps.select{ |dump| dump.ext != 'tgz' })

    dumps = Dump.list(options)
    leave = (options[:leave] || 5).to_i
    to_delete.concat(dumps[0, dumps.length - leave]) if dumps.length > leave

    to_delete.each do |dump|
      dump.lock do
        begin
          dump.path.unlink
          puts "Deleted #{dump.path}"
        rescue => e
          $stderr.puts "Can not delete #{dump.path} — #{e}"
        end
      end
    end
  end
end
