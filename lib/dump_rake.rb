# encoding: UTF-8

require 'pathname'
require 'find'
require 'fileutils'
require 'zlib'
require 'tempfile'

require 'rake'
require 'archive/tar/minitar'
require 'dump_rake/archive_tar_minitar_fix'
require 'progress'

class DumpRake
  class << self
    def versions(options = {})
      Dump.list(options).each do |dump|
        puts DumpRake::Env[:show_size] || $stdout.tty? ? "#{dump.human_size.to_s.rjust(7)}\t#{dump}" : dump
        begin
          case options[:summary].to_s.downcase[0, 1]
          when *%w[1 t y]
            puts DumpReader.summary(dump.path)
            puts
          when *%w[2 s]
            puts DumpReader.summary(dump.path, :schema => true)
            puts
          end
        rescue => e
          $stderr.puts "Error reading dump: #{e}"
          $stderr.puts
        end
      end
    end

    def create(options = {})
      dump = Dump.new(options.merge(:dir => File.join(DumpRake::RailsRoot, 'dump')))

      DumpWriter.create(dump.tmp_path)

      File.rename(dump.tmp_path, dump.tgz_path)
      puts File.basename(dump.tgz_path)
    end

    def restore(options = {})
      dump = Dump.list(options).last

      if dump
        DumpReader.restore(dump.path)
      else
        $stderr.puts 'Avaliable versions:'
        $stderr.puts Dump.list
      end
    end

    def cleanup(options = {})
      unless options[:leave].nil? || /^\d+$/ =~ options[:leave] || options[:leave].downcase == 'none'
        fail 'LEAVE should be number or "none"'
      end

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
end

%w[rails_root assets table_manipulation dump dump_reader dump_writer env].each do |file|
  require "dump_rake/#{file}"
end
