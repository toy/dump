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
    if options[:like]
      puts Dump.like(options[:like])
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

  def self.restore(options = {})
    dump = if options[:like]
      Dump.like(options[:like]).last
    else
      Dump.last
    end

    if dump
      DumpReader.restore(dump.path)
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
