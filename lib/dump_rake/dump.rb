class DumpRake
  class Dump
    def self.list(options = {})
      dumps = Dir[File.join(RAILS_ROOT, 'dump', '*.tgz')].sort.map{ |path| new(path) }
      dumps = dumps.select{ |dump| dump.name[options[:like]] } if options[:like]
      dumps
    end

    def initialize(path)
      @path = Pathname(path)
    end

    def path
      @path
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

    def with_env(key, value)
      old_value, ENV[key] = ENV[key], value
      begin
        yield
      ensure
        ENV[key] = old_value
      end
    end
  end
end
