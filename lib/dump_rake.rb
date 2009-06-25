require 'rubygems'
gem 'progress', '>= 0.0.6'

require 'pathname'
require 'find'
require 'fileutils'
require 'zlib'

require 'rake'
require 'archive/tar/minitar'
require 'progress'

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

    #TODO - send tgz name to writer and rename there
    path = File.join(RAILS_ROOT, 'dump')
    tmp_name = File.join(path, "#{name}.tmp")
    tgz_name = File.join(path, "#{name}.tgz")

    DumpWriter.create(tmp_name)

    File.rename(tmp_name, tgz_name)
    puts File.basename(tgz_name)
  end

  def self.restore(version = nil)
    dump = if version.nil?
      Dump.last
    else
      Dump.like(version).last
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
