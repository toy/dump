$: << File.join(File.dirname(__FILE__), '../../lib')
require 'dump_rake'

task :assets do
  ENV['ASSETS'] ||= File.readlines(File.join(DumpRake::RailsRoot, 'config/assets')).map(&:strip).grep(/^[^#]/).join(':')
end

namespace :assets do
  desc "Delete assets" << DumpRake::Env.explain_variables_for_command(:assets)
  task :delete => :assets do
    ENV['ASSETS'].split(':').each do |asset|
      path = File.expand_path(asset, DumpRake::RailsRoot)
      if path[0, DumpRake::RailsRoot.length] == DumpRake::RailsRoot # asset must be in rails root
        Dir[File.join(path, '*')].each do |child|
          FileUtils.remove_entry(child)
        end
      end
    end
  end
end
