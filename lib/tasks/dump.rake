# frozen_string_literal: true

require 'dump'

desc "Short for dump:create#{Dump::Env.explain_variables_for_command(:create)}"
task :dump => 'dump:create'

namespace :dump do
  desc "Show avaliable versions#{Dump::Env.explain_variables_for_command(:versions)}"
  task :versions => :environment do
    Dump.versions(Dump::Env.for_command(:versions))
  end

  desc "Create dump#{Dump::Env.explain_variables_for_command(:create)}"
  task :create => :environment do
    Dump.create(Dump::Env.for_command(:create))
  end

  desc "Restore dump#{Dump::Env.explain_variables_for_command(:restore)}"
  task :restore => :environment do
    Dump.restore(Dump::Env.for_command(:restore))
  end

  desc "Cleanup dumps#{Dump::Env.explain_variables_for_command(:cleanup)}"
  task :cleanup => :environment do
    Dump.cleanup(Dump::Env.for_command(:cleanup))
  end
end
