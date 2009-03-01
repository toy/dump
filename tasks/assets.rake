task :assets do
  ENV['ASSETS'] ||= File.readlines(File.join(RAILS_ROOT, 'config', 'assets')).map(&:strip).reject{ |path| path[0,1] == '#' }.join(':')
end

namespace :assets do
  desc 'Delete assets'
  task :delete => :assets do
    ENV['ASSETS'].split(':').each do |asset|
      path = File.expand_path(asset, RAILS_ROOT)
      if File.dirname(path)[0, RAILS_ROOT.length] == RAILS_ROOT # asset must be in RAILS_ROOT
        Dir[File.join(path, '*')].each do |path|
          FileUtils.remove_entry_secure(path)
        end
      end
    end
  end
end
