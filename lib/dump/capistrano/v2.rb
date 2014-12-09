# encoding: UTF-8

require 'fileutils'
require 'shellwords'

require 'dump/continious_timeout'
require 'dump/env'

require 'active_support/core_ext/object/blank'

require 'English'

Capistrano::Configuration.instance(:i_need_this!).load do
  namespace :dump do
    def dump_command(command, env = {})
      rake = env.delete(:rake) || 'rake'

      # stringify_keys! from activesupport
      Dump::Env.stringify!(env)

      env.update(Dump::Env.for_command(command, true))

      cmd = %W[-s dump:#{command}]
      cmd += env.sort.map{ |key, value| "#{key}=#{value}" }
      "#{rake} #{cmd.shelljoin}"
    end

    def fetch_rails_env
      fetch(:rails_env, 'production')
    end

    def got_rsync?
      `which rsync`
      $CHILD_STATUS.success?
    end

    def do_transfer_via(via, direction, from, to)
      case via
      when :rsync
        if run_local('which rsync').present? && $CHILD_STATUS.success?
          execute_on_servers do |servers|
            commands = servers.map do |server|
              target = sessions[server]
              user = target.options[:user] || fetch(:user, nil)
              host = target.host
              port = target.options[:port]
              full_host = "#{"#{user}@" if user.present?}#{host}"

              ssh = port.present? ? "ssh -p #{port}" : 'ssh'
              cmd = %W[rsync -P -e #{ssh} --timeout=15]
              case direction
              when :up
                cmd << from << "#{full_host}:#{to}"
              when :down
                cmd << "#{full_host}:#{from}" << to
              else
                fail "Don't know how to transfer in direction #{direction}"
              end
              cmd.shelljoin
            end
            commands.each do |cmd|
              logger.info cmd if logger

              3.times do
                break if system(cmd)
                break unless [10, 11, 12, 23, 30, 35].include?($CHILD_STATUS.exitstatus)
              end
              fail "rsync returned #{$CHILD_STATUS.exitstatus}" unless $CHILD_STATUS.success?
            end
          end
        end
      when :sftp, :scp
        Dump::ContiniousTimeout.timeout 15 do |thread|
          transfer(direction, from, to, :via => via) do |_channel, _path, transfered, total|
            thread.defer
            progress = if transfered < total
              format("\e[1m%5.1f%%\e[0m", transfered * 100.0 / total)
            else
              '100%'
            end
            $stderr << "\rTransfering: #{progress}"
          end
        end
      else
        fail "Unknown transfer method #{via}"
      end
    end

    def do_transfer(direction, from, to)
      via = Dump::Env[:transfer_via]
      case via && via.downcase
      when nil
        if got_rsync?
          do_transfer_via(:rsync, direction, from, to)
        else
          $stderr.puts 'To transfer using rsync — make rsync binary accessible and verify that remote host can work with rsync through ssh'
          begin
            do_transfer_via(:sftp, direction, from, to)
          rescue => e
            $stderr.puts e
            do_transfer_via(:scp, direction, from, to)
          end
        end
      when 'rsync'
        do_transfer_via(:rsync, direction, from, to)
      when 'sftp'
        do_transfer_via(:sftp, direction, from, to)
      when 'scp'
        do_transfer_via(:scp, direction, from, to)
      else
        fail "Unknown transfer method #{via}"
      end
    end

    def with_additional_tags(*tags)
      tags = [tags, Dump::Env[:tags]].flatten.select(&:present?).join(',')
      Dump::Env.with_env(:tags => tags) do
        yield
      end
    end

    def print_and_return_or_fail
      out = yield
      fail 'Failed creating dump' if out.blank?
      print out
      out.strip
    end

    def run_local(cmd)
      `#{cmd}`
    end

    def run_remote(cmd)
      output = ''
      run(cmd) do |_channel, io, data|
        case io
        when :out
          output << data
        when :err
          $stderr << data
        end
      end
      output
    end

    def last_part_of_last_line(out)
      line = out.strip.split(/\s*[\n\r]\s*/).last
      line.split("\t").last if line
    end

    def fetch_rake
      fetch(:rake, nil)
    end

    def auto_backup?
      !Dump::Env.no?(:backup)
    end

    namespace :local do
      desc 'Shorthand for dump:local:create' << Dump::Env.explain_variables_for_command(:create)
      task :default, :roles => :db, :only => {:primary => true} do
        local.create
      end

      desc 'Create local dump' << Dump::Env.explain_variables_for_command(:create)
      task :create, :roles => :db, :only => {:primary => true} do
        print_and_return_or_fail do
          with_additional_tags('local') do
            run_local(dump_command(:create))
          end
        end
      end

      desc 'Restore local dump' << Dump::Env.explain_variables_for_command(:restore)
      task :restore, :roles => :db, :only => {:primary => true} do
        run_local(dump_command(:restore))
      end

      desc 'Versions of local dumps' << Dump::Env.explain_variables_for_command(:versions)
      task :versions, :roles => :db, :only => {:primary => true} do
        print run_local(dump_command(:versions, :show_size => true))
      end

      desc 'Cleanup local dumps' << Dump::Env.explain_variables_for_command(:cleanup)
      task :cleanup, :roles => :db, :only => {:primary => true} do
        print run_local(dump_command(:cleanup))
      end

      desc 'Upload dump' << Dump::Env.explain_variables_for_command(:transfer)
      task :upload, :roles => :db, :only => {:primary => true} do
        file = Dump::Env.with_env(:summary => nil) do
          last_part_of_last_line(run_local(dump_command(:versions)))
        end
        if file
          do_transfer :up, "dump/#{file}", "#{current_path}/dump/#{file}"
        end
      end
    end

    namespace :remote do
      desc 'Shorthand for dump:remote:create' << Dump::Env.explain_variables_for_command(:create)
      task :default, :roles => :db, :only => {:primary => true} do
        remote.create
      end

      desc 'Create remote dump' << Dump::Env.explain_variables_for_command(:create)
      task :create, :roles => :db, :only => {:primary => true} do
        print_and_return_or_fail do
          with_additional_tags('remote') do
            run_remote("cd #{current_path}; #{dump_command(:create, :rake => fetch_rake, :RAILS_ENV => fetch_rails_env, :PROGRESS_TTY => '+')}")
          end
        end
      end

      desc 'Restore remote dump' << Dump::Env.explain_variables_for_command(:restore)
      task :restore, :roles => :db, :only => {:primary => true} do
        run_remote("cd #{current_path}; #{dump_command(:restore, :rake => fetch_rake, :RAILS_ENV => fetch_rails_env, :PROGRESS_TTY => '+')}")
      end

      desc 'Versions of remote dumps' << Dump::Env.explain_variables_for_command(:versions)
      task :versions, :roles => :db, :only => {:primary => true} do
        print run_remote("cd #{current_path}; #{dump_command(:versions, :rake => fetch_rake, :RAILS_ENV => fetch_rails_env, :PROGRESS_TTY => '+', :show_size => true)}")
      end

      desc 'Cleanup of remote dumps' << Dump::Env.explain_variables_for_command(:cleanup)
      task :cleanup, :roles => :db, :only => {:primary => true} do
        print run_remote("cd #{current_path}; #{dump_command(:cleanup, :rake => fetch_rake, :RAILS_ENV => fetch_rails_env, :PROGRESS_TTY => '+')}")
      end

      desc 'Download dump' << Dump::Env.explain_variables_for_command(:transfer)
      task :download, :roles => :db, :only => {:primary => true} do
        file = Dump::Env.with_env(:summary => nil) do
          last_part_of_last_line(run_remote("cd #{current_path}; #{dump_command(:versions, :rake => fetch_rake, :RAILS_ENV => fetch_rails_env, :PROGRESS_TTY => '+')}"))
        end
        if file
          FileUtils.mkpath('dump')
          do_transfer :down, "#{current_path}/dump/#{file}", "dump/#{file}"
        end
      end
    end

    desc 'Shorthand for dump:local:upload' << Dump::Env.explain_variables_for_command(:transfer)
    task :upload, :roles => :db, :only => {:primary => true} do
      local.upload
    end

    desc 'Shorthand for dump:remote:download' << Dump::Env.explain_variables_for_command(:transfer)
    task :download, :roles => :db, :only => {:primary => true} do
      remote.download
    end

    namespace :mirror do
      desc 'Creates local dump, uploads and restores on remote' << Dump::Env.explain_variables_for_command(:mirror)
      task :up, :roles => :db, :only => {:primary => true} do
        auto_backup = if auto_backup?
          with_additional_tags('auto-backup') do
            remote.create
          end
        end
        if !auto_backup? || auto_backup.present?
          file = with_additional_tags('mirror') do
            local.create
          end
          if file.present?
            Dump::Env.with_clean_env(:like => file) do
              local.upload
              remote.restore
            end
          end
        end
      end

      desc 'Creates remote dump, downloads and restores on local' << Dump::Env.explain_variables_for_command(:mirror)
      task :down, :roles => :db, :only => {:primary => true} do
        auto_backup = if auto_backup?
          with_additional_tags('auto-backup') do
            local.create
          end
        end
        if !auto_backup? || auto_backup.present?
          file = with_additional_tags('mirror') do
            remote.create
          end
          if file.present?
            Dump::Env.with_clean_env(:like => file) do
              remote.download
              local.restore
            end
          end
        end
      end
    end

    namespace :backup do
      desc 'Shorthand for dump:backup:create' << Dump::Env.explain_variables_for_command(:backup)
      task :default, :roles => :db, :only => {:primary => true} do
        backup.create
      end

      desc "Creates remote dump and downloads to local (desc defaults to 'backup')" << Dump::Env.explain_variables_for_command(:backup)
      task :create, :roles => :db, :only => {:primary => true} do
        file = with_additional_tags('backup') do
          remote.create
        end
        if file.present?
          Dump::Env.with_clean_env(:like => file) do
            remote.download
          end
        end
      end

      desc 'Uploads dump with backup tag and restores it on remote' << Dump::Env.explain_variables_for_command(:backup_restore)
      task :restore, :roles => :db, :only => {:primary => true} do
        file = with_additional_tags('backup') do
          last_part_of_last_line(run_local(dump_command(:versions)))
        end
        if file.present?
          Dump::Env.with_clean_env(:like => file) do
            local.upload
            remote.restore
          end
        end
      end
    end
  end

  after 'deploy:update_code' do
    from, to = %W[#{shared_path}/dump #{release_path}/dump]
    run "mkdir -p #{from}; rm -rf #{to}; ln -s #{from} #{to}"
  end
end
