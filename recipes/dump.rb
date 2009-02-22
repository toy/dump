def run_local(cmd)
  `#{cmd}`
end

namespace :dump do
  def dump_command(command)
    cmd = "rake -s dump:#{command}"
    case command
    when :create
      desc = ENV['DESC'] || ENV['DESCRIPTION']
      cmd += " DESC=#{desc.inspect}" if desc
    when :restore, :versions
      ver = ENV['VER'] || ENV['VERSION']
      cmd += " VER=#{ver.inspect}" if ver
    end
    cmd
  end

  namespace :local do
    desc "Create local dump"
    task :create, :roles => :db, :only => {:primary => true} do
      out = run_local(dump_command(:create))
      print out
      out.strip
    end

    desc "Restore local dump"
    task :restore, :roles => :db, :only => {:primary => true} do
      run_local(dump_command(:restore))
    end

    desc "Versions of local dumps"
    task :versions, :roles => :db, :only => {:primary => true} do
      print run_local(dump_command(:versions))
    end

    desc "Upload dump"
    task :upload, :roles => :db, :only => {:primary => true} do
      files = run_local(dump_command(:versions)).split("\n")
      if file = files.last
        transfer :up, "dump/#{file}", "#{current_path}/dump/#{file}", :via => :scp
      end
    end
  end

  namespace :remote do
    desc "Create remote dump"
    task :create, :roles => :db, :only => {:primary => true} do
      out = capture("cd #{current_path}; #{dump_command(:create)}")
      print out
      out.strip
    end

    desc "Restore remote dump"
    task :restore, :roles => :db, :only => {:primary => true} do
      run "cd #{current_path}; #{dump_command(:restore)}"
    end

    desc "Versions of remote dumps"
    task :versions, :roles => :db, :only => {:primary => true} do
      print capture("cd #{current_path}; #{dump_command(:versions)}")
    end

    desc "Download dump"
    task :download, :roles => :db, :only => {:primary => true} do
      files = capture("cd #{current_path}; #{dump_command(:versions)}").split("\n")
      if file = files.last
        transfer :down, "#{current_path}/dump/#{file}", "dump/#{file}", :via => :scp
      end
    end
  end

  namespace :mirror do
    desc "Creates local dump, uploads and restores on remote"
    task :up, :roles => :db, :only => {:primary => true} do
      file = local.create
      unless file.blank?
        with_env('VER', file) do
          local.upload
          remote.restore
        end
      end
    end

    desc "Creates remote dump, downloads and restores on local"
    task :down, :roles => :db, :only => {:primary => true} do
      file = remote.create
      unless file.blank?
        with_env('VER', file) do
          remote.download
          local.restore
        end
      end
    end
  end
end
