desc 'Short for dump:create'
task :dump => 'dump:create'

namespace :dump do
  desc 'Show avaliable versions, use version as for restore to show only matching dumps'
  task :versions => :environment do
    DumpRake.versions(DumpRake::Env.for_command(:versions))
  end

  desc 'Create dump DESC[RIPTION]="meaningfull description"'
  task :create => :environment do
    DumpRake.create(DumpRake::Env.for_command(:create))
  end

  desc "Restore dump, use VER[SION]=uniq part of dump name to select which dump to use (last dump is the default)"
  task :restore => :environment do
    DumpRake.restore(DumpRake::Env.for_command(:restore))
  end
end
