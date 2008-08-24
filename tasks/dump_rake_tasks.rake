namespace :db do
  namespace :dump do
    desc 'Create db dump'
    task :create => :environment do
      Dump.create
    end

    desc 'Restore db dump, use V=xxxxxxxxxxxxxx to select which dump to use (last is the default)'
    task :restore => :environment do
      Dump.restore(ENV['V'] ? ENV['V'] : :last)
    end

    namespace :restore do
      desc 'Restore to last dump'
      task :last => :environment do
        Dump.restore(:last)
      end

      desc 'Restore to first dump'
      task :first => :environment do
        Dump.restore(:first)
      end
    end
  end
end

class Dump
  def self.create
    ActiveRecord::Base.establish_connection
    time = Time.now.utc.strftime("%Y%m%d%H%M%S")
    File.open(File.join(RAILS_ROOT, 'db', "dump_#{time}.yml"), 'w') do |f|
      ActiveRecord::Base.connection.select_values('SHOW TABLES').each do |table_name|
        data = ActiveRecord::Base.connection.select_all("SELECT * FROM `#{table_name}`")
        YAML.dump({table_name => data}, f)
      end
    end
  end
  
  def self.restore(which)
    puts 'Not yet implemented :)'
    # available = Dir.glob(File.join(RAILS_ROOT, 'db', 'dump_*.yml')).sort
    
    # variants = {}
    # available.each do |path|
    # end
    # .collect do |path|
    #   File.basename(path)
    # end

    
    
    # puts which
    # puts avaliable
    # task :restore => :environment do
    #   ActiveRecord::Base.establish_connection
    #   time = Time.now.utc.strftime("%Y%m%d%H%M%S")
    #   File.open(File.join(RAILS_ROOT, 'db', "dump_#{time}.yml"), 'w') do |f|
    #     ActiveRecord::Base.connection.select_values('SHOW TABLES').each do |table_name|
    #       data = ActiveRecord::Base.connection.select_all("SELECT * FROM `#{table_name}`")
    #       YAML.dump({table_name => data}, f)
    #     end
    #   end
    # end
  end
end