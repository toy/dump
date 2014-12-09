require 'dump'

task :assets do
  ENV['ASSETS'] ||= Dump::Assets.assets
end

namespace :assets do
  desc 'Delete assets' << Dump::Env.explain_variables_for_command(:assets)
  task :delete => :assets do
    ENV['ASSETS'].split(':').each do |asset|
      Dump::Assets.glob_asset_children(asset, '*').each do |child|
        FileUtils.remove_entry(child)
      end
    end
  end
end
