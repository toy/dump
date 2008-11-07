namespace :db do
  namespace :dump do
    desc 'Create db dump'
    task :create => :environment do
      DumpRake.create
    end

    desc "Restore db dump, use VERSION=yyyymmddhhmmss to select which dump to use (last is the default)"
    task :restore => :environment do
      DumpRake.restore(ENV['VERSION'] || :last)
    end
    
    namespace :restore do
      desc 'Restore to last dump'
      task :last => :environment do
        DumpRake.restore(:last)
      end
    
      desc 'Restore to first dump'
      task :first => :environment do
        DumpRake.restore(:first)
      end
    end
  end
end
