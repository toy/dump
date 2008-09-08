namespace :db do
  namespace :dump do
    desc 'Create db dump'
    task :create => :environment do
      Dump.create
    end

    # desc 'Restore db dump, use V=xxxxxxxxxxxxxx to select which dump to use (last is the default)'
    desc 'Restore last db dump'
    task :restore => [:environment, 'db:schema:load'] do
      Dump.restore
      # (ENV['V'] ? ENV['V'] : :last)
    end

    # namespace :restore do
    #   desc 'Restore to last dump'
    #   task :last => :environment do
    #     Dump.restore(:last)
    #   end
    # 
    #   desc 'Restore to first dump'
    #   task :first => :environment do
    #     Dump.restore(:first)
    #   end
    # end
  end
end

class Dump
  def self.interesting_tables
    ActiveRecord::Base.connection.tables - %w(schema_info schema_migrations sessions public_exceptions)
  end

  def self.create
    ActiveRecord::Base.establish_connection
    time = Time.now.utc.strftime("%Y%m%d%H%M%S")
    path = File.join(RAILS_ROOT, 'db', 'dump', time)
    FileUtils.mkdir_p(path)

    interesting_tables.each do |table|
      puts "Dumping #{table}"
      File.open(File.join(path, "#{table}.yml"), 'w') do |f|
        f.write ActiveRecord::Base.connection.select_all("SELECT * FROM `#{table}`").to_yaml
      end
    end
  end

  def self.restore
    path = Dir.glob(File.join(RAILS_ROOT, 'db', 'dump', '*')).sort.last

    interesting_tables.each do |table|
      ActiveRecord::Base.transaction do
        puts "Loading #{table}"
        YAML.load_file(File.join(path, "#{table}.yml")).each do |fixture|
          ActiveRecord::Base.connection.execute "INSERT INTO #{table} (#{fixture.keys.join(",")}) VALUES (#{fixture.values.collect { |value| ActiveRecord::Base.connection.quote(value) }.join(",")})", 'Fixture Insert'
        end
      end
    end
  end
end