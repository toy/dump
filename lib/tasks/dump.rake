$: << File.join(File.dirname(__FILE__), '..', '..', 'lib')
require 'dump_rake'
require 'dump_rake/env'

desc "Short for dump:create" << DumpRake::Env.explain_variables_for_command(:create)
task :dump => 'dump:create'

namespace :dump do
  desc "Show avaliable versions" << DumpRake::Env.explain_variables_for_command(:versions)
  task :versions => :environment do
    DumpRake.versions(DumpRake::Env.for_command(:versions))
  end

  desc "Create dump" << DumpRake::Env.explain_variables_for_command(:create)
  task :create => :environment do
    DumpRake.create(DumpRake::Env.for_command(:create))
  end

  desc "Restore dump" << DumpRake::Env.explain_variables_for_command(:restore)
  task :restore => :environment do
    DumpRake.restore(DumpRake::Env.for_command(:restore))
  end

  desc "Cleanup dumps" << DumpRake::Env.explain_variables_for_command(:cleanup)
  task :cleanup => :environment do
    DumpRake.cleanup(DumpRake::Env.for_command(:cleanup))
  end
end
