# encoding: UTF-8
# frozen_string_literal: true

require 'dump/rails_root'
require 'dump/table_manipulation'
require 'pathname'

module Dump
  # Base class for dump
  class Snapshot
    include TableManipulation
    def self.list(options = {})
      dumps = Dir[File.join(Dump.rails_root, 'dump', options[:all] ? '*.*' : '*.tgz')].sort.select{ |path| File.file?(path) }.map{ |path| new(path) }
      dumps = dumps.select{ |dump| dump.name[options[:like]] } if options[:like]
      if options[:tags]
        tags = get_filter_tags(options[:tags])
        dumps = dumps.select{ |dump| tags[:any].intersect?(dump.tags.to_set) } if tags[:any].present?
        dumps = dumps.select{ |dump| tags[:all].subset?(dump.tags.to_set) } if tags[:all].present?
        dumps = dumps.reject{ |dump| tags[:none].intersect?(dump.tags.to_set) } if tags[:none].present?
      end
      dumps
    end

    def initialize(path_or_options = {})
      if path_or_options.is_a?(Hash)
        options = path_or_options

        name = Time.now.utc.strftime('%Y%m%d%H%M%S')

        description = clean_description(options[:desc])
        name += "-#{description}" unless description.blank?

        tags = clean_tags(options[:tags])
        name += "@#{tags * ','}" unless tags.empty?

        tgz_name = "#{name}.tgz"

        @path = options[:dir] ? Pathname(options[:dir]) + tgz_name : Pathname(tgz_name)

      else
        @path = Pathname(path_or_options)
      end
    end

    attr_reader :path

    def tgz_path
      path_with_ext('tgz')
    end

    def tmp_path
      path_with_ext('tmp')
    end

    def ==(other)
      path == other.path
    end

    def parts
      @parts ||= if (m = name.match(/^(\d{#{4 + 2 + 2 + 2 + 2 + 2}})(-[^@]+)?((?:@[^@]+)+)?\.(tmp|tgz)$/))
        {
          :time => m[1],
          :desc => m[2] && m[2][1, m[2].length],
          :tags => m[3] && m[3][1, m[3].length],
          :ext => m[4],
        }
      else
        {}
      end
    end

    def time
      parts[:time] && Time.utc(*parts[:time].match(/(\d{4})#{'(\d{2})' * 5}/)[1..6])
    end

    def description
      clean_description(parts[:desc])
    end

    def tags
      clean_tags(parts[:tags])
    end

    def ext
      parts[:ext]
    end

    def name
      @name ||= File.basename(path)
    end
    alias_method :to_s, :name

    def size # rubocop:disable Naming/PredicateMethod
      File.size?(path)
    end

    def human_size
      number = size
      return nil if number.nil?

      degree = 0
      symbols = %w[B K M G T]
      while number >= 1000 && degree < symbols.length - 1
        degree += 1
        number /= 1024.0
      end
      format('%.2f%s', number, symbols[degree])
    end

    def inspect
      "#<#{self.class}:0x#{object_id} #{path}>"
    end

    def lock
      lock = File.open(path, 'r')
      begin
        if lock.flock(File::LOCK_EX | File::LOCK_NB)
          yield
        end
      ensure
        lock.flock(File::LOCK_UN)
        lock.close
      end
    rescue Errno::ENOENT
      nil
    end

    def silence(&block)
      Rails.logger.silence(&block)
    end

  protected

    def assets_root_link
      prefix = 'assets'
      Dir.mktmpdir('assets', File.join(Dump.rails_root, 'tmp')) do |dir|
        Dir.chdir(dir) do
          File.symlink(Dump.rails_root, prefix)
          begin
            yield dir, prefix
          ensure
            File.unlink(prefix)
          end
        end
      end
    end

    def path_with_ext(ext)
      Pathname(path.to_s.sub(/#{parts[:ext]}$/, ext))
    end

    # Cleanup name of dump
    module CleanNParse
      def clean_str(str, additional = nil)
        str.to_s.strip.gsub(/\s+/, ' ').gsub(/[^A-Za-z0-9 \-_#{Regexp.escape(additional.to_s) if additional}]+/, '_')
      end

      def clean_description(description)
        clean_str(description, '()#')[0, 50].strip
      end

      def clean_tag(tag)
        clean_str(tag).downcase.sub(/^-+/, '')[0, 20].strip
      end

      def clean_tags(tags)
        tags.to_s.split(',').map{ |tag| clean_tag(tag) }.uniq.reject(&:blank?).sort
      end

      def get_filter_tags(tags)
        groups = Hash.new{ |hash, key| hash[key] = Set.new }
        tags.to_s.split(',').each do |tag|
          next unless (m = tag.strip.match(/^(-|\+)?(.*)$/))

          type = {'+' => :all, '-' => :none}[m[1]] || :any
          next unless (cleaned_tag = clean_tag(m[2])).present?

          groups[type] << cleaned_tag
        end
        [:any, :all].each do |type|
          if (clashing = (groups[type] & groups[:none])).present?
            fail ArgumentError, "#{type} tags clashes with none ones: #{clashing}"
          end
        end
        groups
      end
    end
    include CleanNParse
    extend CleanNParse
  end
end
