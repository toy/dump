class DumpRake
  class Dump
    def self.list(options = {})
      dumps = Dir[File.join(RAILS_ROOT, 'dump', options[:all] ? '*.*' : '*.tgz')].sort.select{ |path| File.file?(path) }.map{ |path| new(path) }
      dumps = dumps.select{ |dump| dump.name[options[:like]] } if options[:like]
      if options[:tags]
        tags = get_filter_tags(options[:tags])
        dumps = dumps.select{ |dump| (dump.tags & tags[:simple]).present? } if tags[:simple].present?
        dumps = dumps.select{ |dump| (dump.tags & tags[:mandatory]) == tags[:mandatory] } if tags[:mandatory].present?
        dumps = dumps.reject{ |dump| (dump.tags & tags[:forbidden]).present? } if tags[:forbidden].present?
      end
      dumps
    end

    def initialize(path_or_options = {})
      if path_or_options.is_a?(Hash)
        options = path_or_options

        name = Time.now.utc.strftime("%Y%m%d%H%M%S")

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
      @parts ||=
      if m = name.match(/^(\d{#{4+2+2 + 2+2+2}})(-[^@]+)?((?:@[^@]+)+)?\.(tmp|tgz)$/)
        {
          :time => m[1],
          :desc => m[2] && m[2][1, m[2].length],
          :tags => m[3] && m[3][1, m[3].length],
          :ext => m[4]
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
    alias to_s name

    def inspect
      "#<%s:0x%x %s>" % [self.class, object_id, path.to_s.sub(/^.+(?=..\/[^\/]*$)/, '…')]
    end

    def lock
      if lock = File.open(path, 'r')
        begin
          if lock.flock(File::LOCK_EX | File::LOCK_NB)
            yield
          end
        ensure
          lock.flock(File::LOCK_UN)
          lock.close
        end
      end
    end

  protected

    def verify_connection
      ActiveRecord::Base.connection.verify!(0)
    end

    def quote_table_name(table)
      ActiveRecord::Base.connection.quote_table_name(table)
    end

  private

    def schema_tables
      %w(schema_info schema_migrations)
    end

    def path_with_ext(ext)
      Pathname(path.to_s.sub(/#{parts[:ext]}$/, ext))
    end

    def self.instance_accessible_methods(*methods)
      methods.each do |method|
        class_eval <<-code, __FILE__, __LINE__
          def #{method}(*args, &block)
            self.class.#{method}(*args, &block)
          end
        code
      end
    end

    def self.clean_str(str, additional = nil)
      str.to_s.strip.gsub(/\s+/, ' ').gsub(/[^A-Za-z0-9 \-_#{Regexp.escape(additional.to_s) if additional}]+/, '_')
    end
    def self.clean_description(description)
      clean_str(description, '()#')[0, 50].strip
    end
    def self.clean_tag(tag)
      clean_str(tag).downcase.sub(/^\-+/, '')[0, 20].strip
    end
    def self.clean_tags(tags)
      tags.to_s.split(',').map{ |tag| clean_tag(tag) }.uniq.reject(&:blank?).sort
    end
    def self.get_filter_tags(tags)
      groups = Hash.new{ |hash, key| hash[key] = SortedSet.new }
      tags.to_s.split(',').each do |tag|
        if m = tag.strip.match(/^(\-|\+)?(.*)$/)
          type = {'+' => :mandatory, '-' => :forbidden}[m[1]] || :simple
          unless (claned_tag = clean_tag(m[2])).blank?
            groups[type] << claned_tag
          end
        end
      end
      [:simple, :mandatory].each do |type|
        if (clashing = (groups[type] & groups[:forbidden])).present?
          raise "#{type} tags clashes with forbidden ones: #{clashing}"
        end
      end
      groups.each_with_object({}){ |(key, value), hsh| hsh[key] = value.to_a }
    end
    instance_accessible_methods :clean_str, :clean_description, :clean_tag, :clean_tags, :get_filter_tags
  end
end
