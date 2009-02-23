class DumpRake
  class Dump
    def self.list
      Dir.glob(File.join(RAILS_ROOT, 'dump', '*.tgz')).sort.map{ |path| new(path) }
    end
    def self.like(version)
      list.select{ |dump| dump.name[version] }
    end
    def self.last
      list.last
    end

    def initialize(path)
      @path = path
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

    def establish_connection
      ActiveRecord::Base.establish_connection
    end

    def quote_table_name(table)
      ActiveRecord::Base.connection.quote_table_name(table)
    end

    def with_env(key, value)
      old_value, ENV[key] = ENV[key], value
      yield
    ensure
      ENV[key] = old_value
    end
  end
end
