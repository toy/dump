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
