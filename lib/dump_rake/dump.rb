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
        description = clean_description(options[:description])
        name += "-#{description}" unless description.blank?
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

    def clean_description(description)
      description.to_s.downcase.gsub(/[^a-z0-9]+/, ' ').strip[0, 30].strip.gsub(/ /, '-')
    end

  end
end
