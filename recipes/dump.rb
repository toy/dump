# encoding: UTF-8

Capistrano::Configuration.instance(:i_need_this!).load do
  $: << File.join(File.dirname(__FILE__), '../lib')
  
  # Taken from the capistrano code.
  def _cset(name, *args, &block)
    unless exists?(name)
      set(name, *args, &block)
    end
  end

  _cset(:dump_use_rvm, false)    

  def use_rvm_default_shell
    if exists?(:rvm_type)
      default_shell
    end
  end

  namespace :dump do
    namespace :local do
      desc "Creates remote dump, downloads and restores on local"
      task :mirror, :roles => :db, :only => {:primary => true} do
        backup
        use_rvm_default_shell
        file = capture "cd #{current_path} ; RAILS_ENV=#{rails_env} #{rake} dump TAG=capistrano 2> /dev/null"
        download "#{current_path}/dump/#{file.chomp}", "dump/#{file.chomp}"
        puts run_locally "#{rake} dump:restore LIKE=#{file.chomp} 2> /dev/null"
      end
      desc "Create backup locally"
      task :backup, :roles => :db, :only => {:primary => true} do
        run_locally "#{rake} dump TAG=capistrano 2> /dev/null"
      end
      desc "Restore backup locally"
      task :restore, :roles => :db, :only => {:primary => true} do
        puts run_locally "#{rake} dump:restore TAG=capistrano 2> /dev/null"
      end
      desc "Versions of local dumps"
      task :versions, :roles => :db, :only => {:primary => true} do
        puts run_locally "#{rake} dump:versions 2> /dev/null"
      end
      desc "Cleanup local dumps"
      task :cleanup, :roles => :db, :only => {:primary => true} do
        puts run_locally "#{rake} dump:cleanup 2> /dev/null"
      end
    end
    namespace :remote do
      desc "Creates local dump, uploads and restores on remote"
      task :mirror, :roles => :db, :only => {:primary => true} do
        backup
        file = run_locally "#{rake} dump TAG=capistrano 2> /dev/null"
        upload "dump/#{file.chomp}", "#{current_path}/dump/#{file.chomp}"
        use_rvm_default_shell
        run "cd #{current_path} ; RAILS_ENV=#{rails_env} #{rake} dump:restore LIKE=#{file.chomp} 2> /dev/null"
      end
      desc "Create backup on remote server"
      task :backup, :roles => :db, :only => {:primary => true} do
        use_rvm_default_shell
        run "cd #{current_path} ; RAILS_ENV=#{rails_env} #{rake} dump TAG=capistrano 2> /dev/null"
      end
      desc "Restore last backup on remote server"
      task :restore, :roles => :db, :only => {:primary => true} do
        use_rvm_default_shell
        run "cd #{current_path} ; RAILS_ENV=#{rails_env} #{rake} dump:restore TAG=capistrano 2> /dev/null"
      end
      desc "Versions of remote dumps"
      task :versions, :roles => :db, :only => {:primary => true} do
        use_rvm_default_shell
        puts capture "cd #{current_path} ; RAILS_ENV=#{rails_env} #{rake} dump:versions 2> /dev/null"
      end
      desc "Cleanup remote dumps"
      task :cleanup, :roles => :db, :only => {:primary => true} do
        use_rvm_default_shell
        versions = capture "cd #{current_path} ; RAILS_ENV=#{rails_env} #{rake} dump:cleanup 2> /dev/null"
        puts versions if dump_use_rvm
      end
    end
  end
end
