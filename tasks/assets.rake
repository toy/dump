$: << File.join(File.dirname(__FILE__), '..', 'lib')
require 'dump_rake'
require 'dump_rake/env'

task :assets do
  rails_root = (Object.const_defined?('Rails') ? Rails.root : RAILS_ROOT).to_s
  ENV['ASSETS'] ||= File.readlines(File.join(rails_root, 'config', 'assets')).map(&:strip).grep(/^[^#]/).join(':')
end

namespace :assets do
  desc "Delete assets" << DumpRake::Env.explain_variables_for_command(:assets)
  task :delete => :assets do
    rails_root = (Object.const_defined?('Rails') ? Rails.root : RAILS_ROOT).to_s
    ENV['ASSETS'].split(':').each do |asset|
      path = File.expand_path(asset, rails_root)
      if path[0, rails_root.length] == rails_root # asset must be in rails root
        FileUtils.remove_entry_secure(path)
      end
    end
  end
end
