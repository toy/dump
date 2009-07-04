namespace :dump do
  def dump_command(command, env = {})
    cmd = "rake -s dump:#{command}"
    env.each do |key, value|
      cmd += " #{key}=#{value.inspect}"
    end
    case command
    when :create
      desc = ENV['DESC'] || ENV['DESCRIPTION']
      cmd += " DESC=#{desc.inspect}" if desc
    when :restore, :versions
      ver = ENV['VER'] || ENV['VERSION'] || ENV['LIKE']
      cmd += " VER=#{ver.inspect}" if ver
    end
    cmd
  end

  def fetch_rails_env
    fetch(:rails_env, "production")
  end

  def transfer_with_progress(direction, from, to, options = {})
    transfer(direction, from, to, options) do |channel, path, transfered, total|
      print "\rTransfering: %5.1f%%" % (transfered * 100.0 / total)
    end
  end

  def with_default_desc(desc)
    if ENV['DESC'] || ENV['DESCRIPTION']
      yield
    else
      with_env('DESC', desc) do
        yield
      end
    end
  end

  def print_and_return_or_fail
    out = yield
    raise 'Failed creating dump' if out.blank?
    print out
    out.strip
  end

  def run_local(cmd)
    `#{cmd}`
  end

  def run_remote(cmd)
    output = ''
    run(cmd) do |channel, io, data|
      case io
      when :out
        output << data
        STDOUT << data
      when :err
        STDERR << data
      end
    end
    output
  end

  Object.class_eval do
    def blank?
      respond_to?(:empty?) ? empty? : !self
    end

    def present?
      !blank?
    end
  end

  namespace :local do
    desc "Create local dump"
    task :create, :roles => :db, :only => {:primary => true} do
      print_and_return_or_fail do
        with_default_desc('local') do
          run_local(dump_command(:create))
        end
      end
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
        transfer_with_progress :up, "dump/#{file}", "#{current_path}/dump/#{file}", :via => :scp
      end
    end
  end

  namespace :remote do
    desc "Create remote dump"
    task :create, :roles => :db, :only => {:primary => true} do
      print_and_return_or_fail do
        with_default_desc('remote') do
          run_remote("cd #{current_path}; #{dump_command(:create, :RAILS_ENV => fetch_rails_env)}")
        end
      end
    end

    desc "Restore remote dump"
    task :restore, :roles => :db, :only => {:primary => true} do
      run_remote("cd #{current_path}; #{dump_command(:restore, :RAILS_ENV => fetch_rails_env)}")
    end

    desc "Versions of remote dumps"
    task :versions, :roles => :db, :only => {:primary => true} do
      print run_remote("cd #{current_path}; #{dump_command(:versions, :RAILS_ENV => fetch_rails_env)}")
    end

    desc "Download dump"
    task :download, :roles => :db, :only => {:primary => true} do
      files = run_remote("cd #{current_path}; #{dump_command(:versions, :RAILS_ENV => fetch_rails_env)}").split("\n")
      if file = files.last
        FileUtils.mkpath('dump')
        transfer_with_progress :down, "#{current_path}/dump/#{file}", "dump/#{file}", :via => :scp
      end
    end
  end

  namespace :mirror do
    desc "Creates local dump, uploads and restores on remote"
    task :up, :roles => :db, :only => {:primary => true} do
      auto_backup = with_env('DESC', 'auto-backup') do
        remote.create
      end
      if auto_backup.present?
        file = with_default_desc('mirror:up') do
          local.create
        end
        if file.present?
          with_env('VER', file) do
            local.upload
            remote.restore
          end
        end
      end
    end

    desc "Creates remote dump, downloads and restores on local"
    task :down, :roles => :db, :only => {:primary => true} do
      auto_backup = with_env('DESC', 'auto-backup') do
        local.create
      end
      if auto_backup.present?
        file = with_default_desc('mirror:down') do
          remote.create
        end
        if file.present?
          with_env('VER', file) do
            remote.download
            local.restore
          end
        end
      end
    end
  end

  desc "Creates remote dump and downloads to local (desc defaults to 'backup')"
  task :backup, :roles => :db, :only => {:primary => true} do
    file = with_default_desc('backup') do
      remote.create
    end
    if file.present?
      with_env('VER', file) do
        remote.download
      end
    end
  end
end
