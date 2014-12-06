$: << File.join(File.dirname(__FILE__), '../../lib')
require 'dump_rake'

task :assets do
  ENV['ASSETS'] ||= DumpRake::Assets.assets
end

namespace :assets do
  desc 'Delete assets' << DumpRake::Env.explain_variables_for_command(:assets)
  task :delete => :assets do
    ENV['ASSETS'].split(':').each do |asset|
      DumpRake::Assets.glob_asset_children(asset, '*').each do |child|
        FileUtils.remove_entry(child)
      end
    end
  end
end
