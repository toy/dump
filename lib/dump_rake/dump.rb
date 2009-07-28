class DumpRake
  class Dump
    def self.list(options = {})
      dumps = Dir[File.join(RAILS_ROOT, 'dump', '*.tgz')].sort.map{ |path| new(path) }
      dumps = dumps.select{ |dump| dump.name[options[:like]] } if options[:like]
      dumps
    end

    def initialize(path_or_options = {})
      if path_or_options.is_a?(Hash)
        options = path_or_options

        name = Time.now.utc.strftime("%Y%m%d%H%M%S")

        description = clean_description(options[:desc])
        name += "-#{description}" unless description.blank?

        tags = clean_tags(options[:tags])
        name += tags.map{ |tag| "@#{tag}" }.join('')

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

    def name
      @name ||= File.basename(path)
    end
    alias to_s name

  protected

    def verify_connection
      ActiveRecord::Base.connection.verify!(0)
    end

    def quote_table_name(table)
      ActiveRecord::Base.connection.quote_table_name(table)
    end

  private

    def path_with_ext(ext)
      Pathname(path.to_s.sub(/#{Regexp.escape(path.extname)}$/, ".#{ext}"))
    end

    def clean_str(str, length, additional = nil)
      str.to_s.strip.gsub(/\s+/, ' ').gsub(/[^A-Za-z0-9 \-_#{Regexp.escape(additional.to_s)}]+/, '_')[0, length].strip
    end

    def clean_description(description)
      clean_str(description, 50, '()#')
    end

    def clean_tag(tag)
      clean_str(tag, 20).downcase
    end

    def clean_tags(tags)
      tags.to_s.split(',').map{ |tag| clean_tag(tag) }.uniq.reject{ |tag| tag.blank? }.sort
    end
  end
end
