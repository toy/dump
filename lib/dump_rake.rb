# encoding: UTF-8

require 'fileutils'

require 'rake'
require 'progress'

require 'dump_rake/rails_root'
require 'dump_rake/snapshot'
require 'dump_rake/reader'
require 'dump_rake/writer'
require 'dump_rake/env'

# Main interface
module DumpRake
  class << self
    def versions(options = {})
      Snapshot.list(options).each do |dump|
        if DumpRake::Env[:show_size] || $stdout.tty?
          puts "#{dump.human_size.to_s.rjust(7)}\t#{dump}"
        else
          puts dump
        end
        begin
          case options[:summary].to_s.downcase[0, 1]
          when *%w[1 t y]
            puts Reader.summary(dump.path)
            puts
          when *%w[2 s]
            puts Reader.summary(dump.path, :schema => true)
            puts
          end
        rescue => e
          $stderr.puts "Error reading dump: #{e}"
          $stderr.puts
        end
      end
    end

    def create(options = {})
      dump = Snapshot.new(options.merge(:dir => File.join(DumpRake::RailsRoot, 'dump')))

      Writer.create(dump.tmp_path)

      File.rename(dump.tmp_path, dump.tgz_path)
      puts File.basename(dump.tgz_path)
    end

    def restore(options = {})
      dump = Snapshot.list(options).last

      if dump
        Reader.restore(dump.path)
      else
        $stderr.puts 'Avaliable versions:'
        $stderr.puts Snapshot.list
      end
    end

    def cleanup(options = {})
      unless options[:leave].nil? || /^\d+$/ =~ options[:leave] || options[:leave].downcase == 'none'
        fail 'LEAVE should be number or "none"'
      end

      to_delete = []

      all_dumps = Snapshot.list(options.merge(:all => true))
      to_delete.concat(all_dumps.select{ |dump| dump.ext != 'tgz' })

      dumps = Snapshot.list(options)
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
