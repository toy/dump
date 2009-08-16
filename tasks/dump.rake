desc 'Short for dump:create'
task :dump => 'dump:create'

namespace :dump do
  desc 'Show avaliable versions'
  task :versions => :environment do
    DumpRake.versions(DumpRake::Env.for_command(:versions))
  end

  desc 'Create dump'
  task :create => :environment do
    DumpRake.create(DumpRake::Env.for_command(:create))
  end

  desc "Restore dump"
  task :restore => :environment do
    DumpRake.restore(DumpRake::Env.for_command(:restore))
  end

  desc "Cleanup dumps"
  task :cleanup => :environment do
    DumpRake.cleanup(DumpRake::Env.for_command(:cleanup))
  end
end
