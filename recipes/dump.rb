$: << File.join(File.dirname(__FILE__), '..', 'lib')
require 'dump_rake/env'
require 'shell_escape'

namespace :dump do
  def dump_command(command, env = {})
    rake = env.delete(:rake) || 'rake'

    # stringify_keys! from activesupport
    env.keys.each do |key|
      env[key.to_s] = env.delete(key)
    end

    add_envs = case command
    when :create
      [:desc]
    when :restore, :versions
      [:like]
    end

    add_envs.each do |add_env|
      value = DumpRake::Env[add_env]
      env[DumpRake::Env::DICTIONARY[add_env].first] = value if value
    end

    cmd = %W(#{rake} -s dump:#{command})
    cmd += env.sort.map{ |key, value| "#{key}=#{value}" }
    ShellEscape.command(*cmd)
  end

  def fetch_rails_env
    fetch(:rails_env, "production")
  end

  def transfer_with_progress(direction, from, to, options = {})
    transfer(direction, from, to, options) do |channel, path, transfered, total|
      STDERR << "\rTransfering: %5.1f%%" % (transfered * 100.0 / total)
    end
  end

  def with_default_desc(desc)
    if DumpRake::Env[:desc]
      yield
    else
      DumpRake::Env.with_env(:desc => desc) do
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

  def last_line(out)
    out.strip.split(/\s*[\n\r]\s*/).last
  end

  def fetch_rake
    fetch(:rake, nil)
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
      if file = last_line(run_local(dump_command(:versions)))
        transfer_with_progress :up, "dump/#{file}", "#{current_path}/dump/#{file}", :via => :scp
      end
    end
  end

  namespace :remote do
    desc "Create remote dump"
    task :create, :roles => :db, :only => {:primary => true} do
      print_and_return_or_fail do
        with_default_desc('remote') do
          run_remote("cd #{current_path}; #{dump_command(:create, :rake => fetch_rake, :RAILS_ENV => fetch_rails_env, :PROGRESS_TTY => '+')}")
        end
      end
    end

    desc "Restore remote dump"
    task :restore, :roles => :db, :only => {:primary => true} do
      run_remote("cd #{current_path}; #{dump_command(:restore, :rake => fetch_rake, :RAILS_ENV => fetch_rails_env, :PROGRESS_TTY => '+')}")
    end

    desc "Versions of remote dumps"
    task :versions, :roles => :db, :only => {:primary => true} do
      print run_remote("cd #{current_path}; #{dump_command(:versions, :rake => fetch_rake, :RAILS_ENV => fetch_rails_env, :PROGRESS_TTY => '+')}")
    end

    desc "Download dump"
    task :download, :roles => :db, :only => {:primary => true} do
      if file = last_line(run_remote("cd #{current_path}; #{dump_command(:versions, :rake => fetch_rake, :RAILS_ENV => fetch_rails_env, :PROGRESS_TTY => '+')}"))
        FileUtils.mkpath('dump')
        transfer_with_progress :down, "#{current_path}/dump/#{file}", "dump/#{file}", :via => :scp
      end
    end
  end

  namespace :mirror do
    desc "Creates local dump, uploads and restores on remote"
    task :up, :roles => :db, :only => {:primary => true} do
      auto_backup = DumpRake::Env.with_env(:desc => 'auto-backup') do
        remote.create
      end
      if auto_backup.present?
        file = with_default_desc('mirror:up') do
          local.create
        end
        if file.present?
          DumpRake::Env.with_env(:like => file) do
            local.upload
            remote.restore
          end
        end
      end
    end

    desc "Creates remote dump, downloads and restores on local"
    task :down, :roles => :db, :only => {:primary => true} do
      auto_backup = DumpRake::Env.with_env(:desc => 'auto-backup') do
        local.create
      end
      if auto_backup.present?
        file = with_default_desc('mirror:down') do
          remote.create
        end
        if file.present?
          DumpRake::Env.with_env(:like => file) do
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
      DumpRake::Env.with_env(:like => file) do
        remote.download
      end
    end
  end
end
