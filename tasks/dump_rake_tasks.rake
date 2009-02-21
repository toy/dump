namespace :dump do
  desc 'Show avaliable versions, use version as for restore to show only matching dumps'
  task :versions => :environment do
    DumpRake.versions(ENV['VER'] || ENV['VERSION'])
  end

  desc 'Create dump DESC[RIPTION]="meaningfull description"'
  task :create => :environment do
    DumpRake.create(:comment => ENV['DESC'] || ENV['DESCRIPTION'])
  end

  desc "Restore dump, use VER[SION]=uniq part of dump name to select which dump to use (last dump is the default)"
  task :restore => :environment do
    DumpRake.restore(ENV['VER'] || ENV['VERSION'] || :last)
  end
end

unless Rake::Task.task_defined?('assets')
  task :assets do
    ENV['ASSETS'] = File.readlines(File.join(RAILS_ROOT, 'config', 'assets')).map(&:strip).join(':')
  end

  namespace :assets do
    desc 'Delete assets'
    task :delete => :assets do
      ENV['ASSETS'].split(':').each do |asset|
        Dir.glob(File.join(RAILS_ROOT, asset, '*')) do |path|
          FileUtils.remove_entry_secure(path)
        end
      end
    end
  end
end
