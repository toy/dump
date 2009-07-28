$: << File.join(File.dirname(__FILE__), '..', 'lib')

desc 'Short for dump:create'
task :dump => 'dump:create'

namespace :dump do
  desc 'Show avaliable versions, use version as for restore to show only matching dumps'
  task :versions => :environment do
    DumpRake.versions(:like => DumpRake::Env[:like])
  end

  desc 'Create dump DESC[RIPTION]="meaningfull description"'
  task :create => :environment do
    DumpRake.create(:description => DumpRake::Env[:desc])
  end

  desc "Restore dump, use VER[SION]=uniq part of dump name to select which dump to use (last dump is the default)"
  task :restore => :environment do
    DumpRake.restore(:like => DumpRake::Env[:like])
  end
end
