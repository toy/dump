# encoding: UTF-8

Capistrano::Configuration.instance(:i_need_this!).load do
  require 'fileutils'
  require 'shellwords'

  require 'dump_rake/continious_timeout'
  require 'dump_rake/env'

  require 'active_support/core_ext/object/blank'

  namespace :dump do
    def dump_command(command, env = {})
      rake = env.delete(:rake) || 'rake'

      # stringify_keys! from activesupport
      DumpRake::Env.stringify!(env)

      env.update(DumpRake::Env.for_command(command, true))

      cmd = %W[-s dump:#{command}]
      cmd += env.sort.map{ |key, value| "#{key}=#{value}" }
      "#{rake} #{cmd.shelljoin}"
    end

    def fetch_rails_env
      fetch(:rails_env, 'production')
    end

    def got_rsync?
      `which rsync`
      $?.success?
    end

    def do_transfer_via(via, direction, from, to)
      case via
      when :rsync
        if run_local('which rsync').present? && $?.success?
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
                raise "Don't know how to transfer in direction #{direction}"
              end
              cmd.shelljoin
            end
            commands.each do |cmd|
              logger.info cmd if logger

              3.times do
                break if system(cmd)
                break unless [10, 11, 12, 23, 30, 35].include?($?.exitstatus)
              end
              raise "rsync returned #{$?.exitstatus}" unless $?.success?
            end
          end
        end
      when :sftp, :scp
        ContiniousTimeout.timeout 15 do |thread|
          transfer(direction, from, to, :via => via) do |channel, path, transfered, total|
            thread.defer
            progress = if transfered < total
              "\e[1m%5.1f%%\e[0m" % (transfered * 100.0 / total)
            else
              '100%'
            end
            $stderr << "\rTransfering: #{progress}"
          end
        end
      else
        raise "Unknown transfer method #{via}"
      end
    end

    def do_transfer(direction, from, to)
      if via = DumpRake::Env[:transfer_via]
        case via.downcase
        when 'rsync'
          do_transfer_via(:rsync, direction, from, to)
        when 'sftp'
          do_transfer_via(:sftp, direction, from, to)
        when 'scp'
          do_transfer_via(:scp, direction, from, to)
        else
          raise "Unknown transfer method #{via}"
        end
      else
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
      end
    end

    def with_additional_tags(*tags)
      tags = [tags, DumpRake::Env[:tags]].flatten.select(&:present?).join(',')
      DumpRake::Env.with_env(:tags => tags) do
        yield
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
        when :err
          $stderr << data
        end
      end
      output
    end

    def last_part_of_last_line(out)
      if line = out.strip.split(/\s*[\n\r]\s*/).last
        line.split("\t").last
      end
    end

    def fetch_rake
      fetch(:rake, nil)
    end

    def auto_backup?
      !DumpRake::Env.no?(:backup)
    end

    namespace :local do
      desc 'Shorthand for dump:local:create' << DumpRake::Env.explain_variables_for_command(:create)
      task :default, :roles => :db, :only => {:primary => true} do
        create
      end

      desc 'Create local dump' << DumpRake::Env.explain_variables_for_command(:create)
      task :create, :roles => :db, :only => {:primary => true} do
        print_and_return_or_fail do
          with_additional_tags('local') do
            run_local(dump_command(:create))
          end
        end
      end

      desc 'Restore local dump' << DumpRake::Env.explain_variables_for_command(:restore)
      task :restore, :roles => :db, :only => {:primary => true} do
        run_local(dump_command(:restore))
      end

      desc 'Versions of local dumps' << DumpRake::Env.explain_variables_for_command(:versions)
      task :versions, :roles => :db, :only => {:primary => true} do
        print run_local(dump_command(:versions, :show_size => true))
      end

      desc 'Cleanup local dumps' << DumpRake::Env.explain_variables_for_command(:cleanup)
      task :cleanup, :roles => :db, :only => {:primary => true} do
        print run_local(dump_command(:cleanup))
      end

      desc 'Upload dump' << DumpRake::Env.explain_variables_for_command(:transfer)
      task :upload, :roles => :db, :only => {:primary => true} do
        file = DumpRake::Env.with_env(:summary => nil) do
          last_part_of_last_line(run_local(dump_command(:versions)))
        end
        if file
          do_transfer :up, "dump/#{file}", "#{current_path}/dump/#{file}"
        end
      end
    end

    namespace :remote do
      desc 'Shorthand for dump:remote:create' << DumpRake::Env.explain_variables_for_command(:create)
      task :default, :roles => :db, :only => {:primary => true} do
        remote.create
      end

      desc 'Create remote dump' << DumpRake::Env.explain_variables_for_command(:create)
      task :create, :roles => :db, :only => {:primary => true} do
        print_and_return_or_fail do
          with_additional_tags('remote') do
            run_remote("cd #{current_path}; #{dump_command(:create, :rake => fetch_rake, :RAILS_ENV => fetch_rails_env, :PROGRESS_TTY => '+')}")
          end
        end
      end

      desc 'Restore remote dump' << DumpRake::Env.explain_variables_for_command(:restore)
      task :restore, :roles => :db, :only => {:primary => true} do
        run_remote("cd #{current_path}; #{dump_command(:restore, :rake => fetch_rake, :RAILS_ENV => fetch_rails_env, :PROGRESS_TTY => '+')}")
      end

      desc 'Versions of remote dumps' << DumpRake::Env.explain_variables_for_command(:versions)
      task :versions, :roles => :db, :only => {:primary => true} do
        print run_remote("cd #{current_path}; #{dump_command(:versions, :rake => fetch_rake, :RAILS_ENV => fetch_rails_env, :PROGRESS_TTY => '+', :show_size => true)}")
      end

      desc 'Cleanup of remote dumps' << DumpRake::Env.explain_variables_for_command(:cleanup)
      task :cleanup, :roles => :db, :only => {:primary => true} do
        print run_remote("cd #{current_path}; #{dump_command(:cleanup, :rake => fetch_rake, :RAILS_ENV => fetch_rails_env, :PROGRESS_TTY => '+')}")
      end

      desc 'Download dump' << DumpRake::Env.explain_variables_for_command(:transfer)
      task :download, :roles => :db, :only => {:primary => true} do
        file = DumpRake::Env.with_env(:summary => nil) do
          last_part_of_last_line(run_remote("cd #{current_path}; #{dump_command(:versions, :rake => fetch_rake, :RAILS_ENV => fetch_rails_env, :PROGRESS_TTY => '+')}"))
        end
        if file
          FileUtils.mkpath('dump')
          do_transfer :down, "#{current_path}/dump/#{file}", "dump/#{file}"
        end
      end
    end

    desc 'Shorthand for dump:local:upload' << DumpRake::Env.explain_variables_for_command(:transfer)
    task :upload, :roles => :db, :only => {:primary => true} do
      local.upload
    end

    desc 'Shorthand for dump:remote:download' << DumpRake::Env.explain_variables_for_command(:transfer)
    task :download, :roles => :db, :only => {:primary => true} do
      remote.download
    end

    namespace :mirror do
      desc 'Creates local dump, uploads and restores on remote' << DumpRake::Env.explain_variables_for_command(:mirror)
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
            DumpRake::Env.with_clean_env(:like => file) do
              local.upload
              remote.restore
            end
          end
        end
      end

      desc 'Creates remote dump, downloads and restores on local' << DumpRake::Env.explain_variables_for_command(:mirror)
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
            DumpRake::Env.with_clean_env(:like => file) do
              remote.download
              local.restore
            end
          end
        end
      end
    end

    namespace :backup do
      desc 'Shorthand for dump:backup:create' << DumpRake::Env.explain_variables_for_command(:backup)
      task :default, :roles => :db, :only => {:primary => true} do
        create
      end

      desc "Creates remote dump and downloads to local (desc defaults to 'backup')" << DumpRake::Env.explain_variables_for_command(:backup)
      task :create, :roles => :db, :only => {:primary => true} do
        file = with_additional_tags('backup') do
          remote.create
        end
        if file.present?
          DumpRake::Env.with_clean_env(:like => file) do
            remote.download
          end
        end
      end

      desc 'Uploads dump with backup tag and restores it on remote' << DumpRake::Env.explain_variables_for_command(:backup_restore)
      task :restore, :roles => :db, :only => {:primary => true} do
        file = with_additional_tags('backup') do
          last_part_of_last_line(run_local(dump_command(:versions)))
        end
        if file.present?
          DumpRake::Env.with_clean_env(:like => file) do
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
