require 'spec_helper'
require 'dump'
require 'capistrano'

describe 'cap dump' do
  before do
    @cap = Capistrano::Configuration.new
    Capistrano::Configuration.instance = @cap
    @cap.load File.expand_path('../../../recipes/dump.rb', __FILE__)
    @remote_path = '/home/test/apps/dummy'
    @cap.set(:current_path, @remote_path)
  end

  def all_dictionary_variables
    Dump::Env::DICTIONARY.each_with_object({}) do |(key, value), filled_env|
      filled_env[key] = value.join(' ')
    end
  end

  def self.test_passing_environment_variables(place, command, command_strings, options = {})
    Dump::Env.variable_names_for_command(command).each do |variable|
      command_string = command_strings[variable]
      Dump::Env::DICTIONARY[variable].each do |name|
        it "passes #{variable} if it is set through environment variable #{name}" do
          violated 'command_string not specified' unless command_string
          full_command_string = command_string
          full_command_string = "cd #{@remote_path}; #{command_string}" if place == :remote
          expect(@cap.dump).to receive(:"run_#{place}").with(full_command_string).and_return(options[:return_value] || '')
          Dump::Env.with_env name => options[:value] || 'some data' do
            cap_task = options[:cap_task] || "dump:#{place}:#{command}"
            grab_output{ @cap.find_and_execute_task(cap_task) }
          end
        end
      end
    end
  end

  describe :dump_command do

    it 'returns escaped string' do
      expect(@cap.dump.dump_command(:hello, :rake => 'rake', 'x x' => 'a b')).to eq('rake -s dump:hello x\\ x\\=a\\ b')
    end

    it 'returns escaped string for complex rake invocation command' do
      expect(@cap.dump.dump_command(:hello, :rake => 'bundler exec rake', 'x x' => 'a b')).to eq('bundler exec rake -s dump:hello x\\ x\\=a\\ b')
    end
  end

  describe 'do_transfer' do
    before do
      allow(@cap.dump).to receive(:do_transfer_via)
    end

    [:up, :down].each do |direction|
      describe direction do
        describe 'if method not set' do

          it 'calls got_rsync?' do
            expect(@cap.dump).to receive(:got_rsync?)
            grab_output{ @cap.dump.do_transfer(direction, 'a.tgz', 'b.tgz') }
          end

          describe 'if got_rsync?' do
            it 'uses rsync' do
              allow(@cap.dump).to receive(:got_rsync?).and_return(true)
              expect(@cap.dump).to receive(:do_transfer_via).with(:rsync, direction, 'a.tgz', 'b.tgz')
              grab_output{ @cap.dump.do_transfer(direction, 'a.tgz', 'b.tgz') }
            end

            it 'raises if rsync fails' do
              allow(@cap.dump).to receive(:got_rsync?).and_return(true)
              expect(@cap.dump).to receive(:do_transfer_via).with(:rsync, direction, 'a.tgz', 'b.tgz').and_raise('problem using rsync')
              expect do
                grab_output{ @cap.dump.do_transfer(direction, 'a.tgz', 'b.tgz') }
              end.to raise_error('problem using rsync')
            end
          end

          describe 'unless got_rsync?' do
            it 'tries sftp' do
              allow(@cap.dump).to receive(:got_rsync?).and_return(false)
              expect(@cap.dump).to receive(:do_transfer_via).with(:sftp, direction, 'a.tgz', 'b.tgz')
              grab_output{ @cap.dump.do_transfer(direction, 'a.tgz', 'b.tgz') }
            end

            it 'tries scp after sftp' do
              allow(@cap.dump).to receive(:got_rsync?).and_return(false)
              expect(@cap.dump).to receive(:do_transfer_via).with(:sftp, direction, 'a.tgz', 'b.tgz').and_raise('problem using sftp')
              expect(@cap.dump).to receive(:do_transfer_via).with(:scp, direction, 'a.tgz', 'b.tgz')
              grab_output{ @cap.dump.do_transfer(direction, 'a.tgz', 'b.tgz') }
            end

            it 'does not rescue if scp also fails' do
              allow(@cap.dump).to receive(:got_rsync?).and_return(false)
              expect(@cap.dump).to receive(:do_transfer_via).with(:sftp, direction, 'a.tgz', 'b.tgz').and_raise('problem using sftp')
              expect(@cap.dump).to receive(:do_transfer_via).with(:scp, direction, 'a.tgz', 'b.tgz').and_raise('problem using scp')
              expect do
                grab_output{ @cap.dump.do_transfer(direction, 'a.tgz', 'b.tgz') }
              end.to raise_error('problem using scp')
            end
          end
        end
      end
    end
  end

  describe 'local' do
    it 'calls local:create' do
      expect(@cap.dump.local).to receive(:create).and_return('')
      @cap.find_and_execute_task('dump:local')
    end

    describe 'versions' do
      it 'calls local rake task' do
        expect(@cap.dump).to receive(:run_local).with('rake -s dump:versions SHOW_SIZE\\=true').and_return('')
        @cap.find_and_execute_task('dump:local:versions')
      end

      test_passing_environment_variables(:local, :versions, {
        :like => 'rake -s dump:versions LIKE\\=some\\ data SHOW_SIZE\\=true',
        :tags => 'rake -s dump:versions SHOW_SIZE\\=true TAGS\\=some\\ data',
        :summary => 'rake -s dump:versions SHOW_SIZE\\=true SUMMARY\\=some\\ data',
      })

      it 'prints result of rake task' do
        allow(@cap.dump).to receive(:run_local).and_return(" 123M\t123123.tgz\n")
        expect(grab_output do
          @cap.find_and_execute_task('dump:local:versions')
        end[:stdout]).to eq(" 123M\t123123.tgz\n")
      end
    end

    describe 'cleanup' do
      it 'calls local rake task' do
        expect(@cap.dump).to receive(:run_local).with('rake -s dump:cleanup').and_return('')
        @cap.find_and_execute_task('dump:local:cleanup')
      end

      test_passing_environment_variables(:local, :cleanup, {
        :like => 'rake -s dump:cleanup LIKE\\=some\\ data',
        :tags => 'rake -s dump:cleanup TAGS\\=some\\ data',
        :leave => 'rake -s dump:cleanup LEAVE\\=some\\ data',
      })

      it 'prints result of rake task' do
        allow(@cap.dump).to receive(:run_local).and_return("123123.tgz\n")
        expect(grab_output do
          @cap.find_and_execute_task('dump:local:cleanup')
        end[:stdout]).to eq("123123.tgz\n")
      end
    end

    describe 'create' do
      it 'raises if dump creation fails' do
        expect(@cap.dump).to receive(:run_local).with('rake -s dump:create TAGS\\=local').and_return('')
        expect do
          @cap.find_and_execute_task('dump:local:create')
        end.to raise_error('Failed creating dump')
      end

      it 'calls local rake task with tag local' do
        expect(@cap.dump).to receive(:run_local).with('rake -s dump:create TAGS\\=local').and_return('123.tgz')
        grab_output do
          @cap.find_and_execute_task('dump:local:create')
        end
      end

      it 'calls local rake task with additional tag local' do
        expect(@cap.dump).to receive(:run_local).with('rake -s dump:create TAGS\\=local,photos').and_return('123.tgz')
        grab_output do
          Dump::Env.with_env :tags => 'photos' do
            @cap.find_and_execute_task('dump:local:create')
          end
        end
      end

      test_passing_environment_variables(:local, :create, {
        :desc => 'rake -s dump:create DESC\\=some\\ data TAGS\\=local',
        :tags => 'rake -s dump:create TAGS\\=local,some\\ data',
        :tables => 'rake -s dump:create TABLES\\=some\\ data TAGS\\=local',
        :assets => 'rake -s dump:create ASSETS\\=some\\ data TAGS\\=local',
      }, :return_value => '123.tgz')

      it 'prints result of rake task' do
        allow(@cap.dump).to receive(:run_local).and_return("123123.tgz\n")
        expect(grab_output do
          @cap.find_and_execute_task('dump:local:create')
        end[:stdout]).to eq("123123.tgz\n")
      end

      it 'returns stripped result of rake task' do
        allow(@cap.dump).to receive(:run_local).and_return("123123.tgz\n")
        grab_output do
          expect(@cap.find_and_execute_task('dump:local:create')).to eq('123123.tgz')
        end
      end
    end

    describe 'restore' do
      it 'calls local rake task' do
        expect(@cap.dump).to receive(:run_local).with('rake -s dump:restore')
        @cap.find_and_execute_task('dump:local:restore')
      end

      test_passing_environment_variables(:local, :restore, {
        :like => 'rake -s dump:restore LIKE\\=some\\ data',
        :tags => 'rake -s dump:restore TAGS\\=some\\ data',
        :migrate_down => 'rake -s dump:restore MIGRATE_DOWN\\=some\\ data',
        :restore_schema => 'rake -s dump:restore RESTORE_SCHEMA\\=some\\ data',
        :restore_tables => 'rake -s dump:restore RESTORE_TABLES\\=some\\ data',
        :restore_assets => 'rake -s dump:restore RESTORE_ASSETS\\=some\\ data',
      })
    end

    describe 'upload' do
      it 'runs rake versions to get avaliable versions' do
        expect(@cap.dump).to receive(:run_local).with('rake -s dump:versions').and_return('')
        @cap.find_and_execute_task('dump:local:upload')
      end

      test_passing_environment_variables(:local, :transfer, {
        :like => 'rake -s dump:versions LIKE\\=some\\ data',
        :tags => 'rake -s dump:versions TAGS\\=some\\ data',
        :summary => 'rake -s dump:versions', # block sending summary to versions
        :transfer_via => 'rake -s dump:versions', # tranfer_via is used internally
      }, :cap_task => 'dump:local:upload')

      it 'does not upload anything if there are no versions avaliable' do
        allow(@cap.dump).to receive(:run_local).and_return('')
        expect(@cap.dump).not_to receive(:do_transfer)
        @cap.find_and_execute_task('dump:local:upload')
      end

      it 'transfers latest version dump' do
        allow(@cap.dump).to receive(:run_local).and_return("100.tgz\n200.tgz\n300.tgz\n")
        expect(@cap.dump).to receive(:do_transfer).with(:up, 'dump/300.tgz', "#{@remote_path}/dump/300.tgz")
        @cap.find_and_execute_task('dump:local:upload')
      end

      it 'handles extra spaces around file names' do
        allow(@cap.dump).to receive(:run_local).and_return("\r\n\r\n\r  100.tgz   \r\n\r\n\r  200.tgz   \r\n\r\n\r  300.tgz   \r\n\r\n\r  ")
        expect(@cap.dump).to receive(:do_transfer).with(:up, 'dump/300.tgz', "#{@remote_path}/dump/300.tgz")
        @cap.find_and_execute_task('dump:local:upload')
      end
    end
  end

  describe 'remote' do
    it 'calls remote:create' do
      expect(@cap.dump.remote).to receive(:create).and_return('')
      @cap.find_and_execute_task('dump:remote')
    end

    describe 'versions' do
      it 'calls remote rake task' do
        expect(@cap.dump).to receive(:run_remote).with("cd #{@remote_path}; rake -s dump:versions PROGRESS_TTY\\=\\+ RAILS_ENV\\=production SHOW_SIZE\\=true").and_return('')
        @cap.find_and_execute_task('dump:remote:versions')
      end

      test_passing_environment_variables(:remote, :versions, {
        :like => 'rake -s dump:versions LIKE\\=some\\ data PROGRESS_TTY\\=\\+ RAILS_ENV\\=production SHOW_SIZE\\=true',
        :tags => 'rake -s dump:versions PROGRESS_TTY\\=\\+ RAILS_ENV\\=production SHOW_SIZE\\=true TAGS\\=some\\ data',
        :summary => 'rake -s dump:versions PROGRESS_TTY\\=\\+ RAILS_ENV\\=production SHOW_SIZE\\=true SUMMARY\\=some\\ data',
      })

      it 'prints result of rake task' do
        allow(@cap.dump).to receive(:run_remote).and_return(" 123M\t123123.tgz\n")
        expect(grab_output do
          @cap.find_and_execute_task('dump:remote:versions')
        end[:stdout]).to eq(" 123M\t123123.tgz\n")
      end

      it 'uses custom rake binary' do
        expect(@cap.dump).to receive(:fetch_rake).and_return('/custom/rake')
        expect(@cap.dump).to receive(:run_remote).with("cd #{@remote_path}; /custom/rake -s dump:versions PROGRESS_TTY\\=\\+ RAILS_ENV\\=production SHOW_SIZE\\=true").and_return('')
        @cap.find_and_execute_task('dump:remote:versions')
      end
    end

    describe 'cleanup' do
      it 'calls remote rake task' do
        expect(@cap.dump).to receive(:run_remote).with("cd #{@remote_path}; rake -s dump:cleanup PROGRESS_TTY\\=\\+ RAILS_ENV\\=production").and_return('')
        @cap.find_and_execute_task('dump:remote:cleanup')
      end

      test_passing_environment_variables(:remote, :cleanup, {
        :like => 'rake -s dump:cleanup LIKE\\=some\\ data PROGRESS_TTY\\=\\+ RAILS_ENV\\=production',
        :tags => 'rake -s dump:cleanup PROGRESS_TTY\\=\\+ RAILS_ENV\\=production TAGS\\=some\\ data',
        :leave => 'rake -s dump:cleanup LEAVE\\=some\\ data PROGRESS_TTY\\=\\+ RAILS_ENV\\=production',
      })

      it 'prints result of rake task' do
        allow(@cap.dump).to receive(:run_remote).and_return("123123.tgz\n")
        expect(grab_output do
          @cap.find_and_execute_task('dump:remote:cleanup')
        end[:stdout]).to eq("123123.tgz\n")
      end

      it 'uses custom rake binary' do
        expect(@cap.dump).to receive(:fetch_rake).and_return('/custom/rake')
        expect(@cap.dump).to receive(:run_remote).with("cd #{@remote_path}; /custom/rake -s dump:cleanup PROGRESS_TTY\\=\\+ RAILS_ENV\\=production").and_return('')
        @cap.find_and_execute_task('dump:remote:cleanup')
      end
    end

    describe 'create' do
      it 'raises if dump creation fails' do
        expect(@cap.dump).to receive(:run_remote).with("cd #{@remote_path}; rake -s dump:create PROGRESS_TTY\\=\\+ RAILS_ENV\\=production TAGS\\=remote").and_return('')
        expect do
          @cap.find_and_execute_task('dump:remote:create')
        end.to raise_error('Failed creating dump')
      end

      it 'calls remote rake task with default rails_env and tag remote' do
        expect(@cap.dump).to receive(:run_remote).with("cd #{@remote_path}; rake -s dump:create PROGRESS_TTY\\=\\+ RAILS_ENV\\=production TAGS\\=remote").and_return('123.tgz')
        grab_output do
          @cap.find_and_execute_task('dump:remote:create')
        end
      end

      it 'calls remote rake task with default rails_env and additional tag remote' do
        expect(@cap.dump).to receive(:run_remote).with("cd #{@remote_path}; rake -s dump:create PROGRESS_TTY\\=\\+ RAILS_ENV\\=production TAGS\\=remote,photos").and_return('123.tgz')
        grab_output do
          Dump::Env.with_env :tags => 'photos' do
            @cap.find_and_execute_task('dump:remote:create')
          end
        end
      end

      it 'calls remote rake task with fetched rails_env and default DESC remote' do
        expect(@cap.dump).to receive(:fetch_rails_env).and_return('dev')
        expect(@cap.dump).to receive(:run_remote).with("cd #{@remote_path}; rake -s dump:create PROGRESS_TTY\\=\\+ RAILS_ENV\\=dev TAGS\\=remote").and_return('123.tgz')
        grab_output do
          @cap.find_and_execute_task('dump:remote:create')
        end
      end

      test_passing_environment_variables(:remote, :create, {
        :desc => 'rake -s dump:create DESC\\=some\\ data PROGRESS_TTY\\=\\+ RAILS_ENV\\=production TAGS\\=remote',
        :tags => 'rake -s dump:create PROGRESS_TTY\\=\\+ RAILS_ENV\\=production TAGS\\=remote,some\\ data',
        :assets => 'rake -s dump:create ASSETS\\=some\\ data PROGRESS_TTY\\=\\+ RAILS_ENV\\=production TAGS\\=remote',
        :tables => 'rake -s dump:create PROGRESS_TTY\\=\\+ RAILS_ENV\\=production TABLES\\=some\\ data TAGS\\=remote',
      }, :return_value => '123.tgz')

      it 'prints result of rake task' do
        allow(@cap.dump).to receive(:run_remote).and_return("123123.tgz\n")
        expect(grab_output do
          @cap.find_and_execute_task('dump:remote:create')
        end[:stdout]).to eq("123123.tgz\n")
      end

      it 'returns stripped result of rake task' do
        allow(@cap.dump).to receive(:run_remote).and_return("123123.tgz\n")
        grab_output do
          expect(@cap.find_and_execute_task('dump:remote:create')).to eq('123123.tgz')
        end
      end

      it 'uses custom rake binary' do
        expect(@cap.dump).to receive(:fetch_rake).and_return('/custom/rake')
        expect(@cap.dump).to receive(:run_remote).with("cd #{@remote_path}; /custom/rake -s dump:create PROGRESS_TTY\\=\\+ RAILS_ENV\\=production TAGS\\=remote").and_return('123.tgz')
        grab_output do
          @cap.find_and_execute_task('dump:remote:create')
        end
      end
    end

    describe 'restore' do
      it 'calls remote rake task with default rails_env' do
        expect(@cap.dump).to receive(:run_remote).with("cd #{@remote_path}; rake -s dump:restore PROGRESS_TTY\\=\\+ RAILS_ENV\\=production")
        @cap.find_and_execute_task('dump:remote:restore')
      end

      it 'calls remote rake task with fetched rails_env' do
        expect(@cap.dump).to receive(:fetch_rails_env).and_return('dev')
        expect(@cap.dump).to receive(:run_remote).with("cd #{@remote_path}; rake -s dump:restore PROGRESS_TTY\\=\\+ RAILS_ENV\\=dev")
        @cap.find_and_execute_task('dump:remote:restore')
      end

      test_passing_environment_variables(:remote, :restore, {
        :like => 'rake -s dump:restore LIKE\\=some\\ data PROGRESS_TTY\\=\\+ RAILS_ENV\\=production',
        :tags => 'rake -s dump:restore PROGRESS_TTY\\=\\+ RAILS_ENV\\=production TAGS\\=some\\ data',
        :migrate_down => 'rake -s dump:restore MIGRATE_DOWN\\=some\\ data PROGRESS_TTY\\=\\+ RAILS_ENV\\=production',
        :restore_schema => 'rake -s dump:restore PROGRESS_TTY\\=\\+ RAILS_ENV\\=production RESTORE_SCHEMA\\=some\\ data',
        :restore_tables => 'rake -s dump:restore PROGRESS_TTY\\=\\+ RAILS_ENV\\=production RESTORE_TABLES\\=some\\ data',
        :restore_assets => 'rake -s dump:restore PROGRESS_TTY\\=\\+ RAILS_ENV\\=production RESTORE_ASSETS\\=some\\ data',
      })

      it 'uses custom rake binary' do
        expect(@cap.dump).to receive(:fetch_rake).and_return('/custom/rake')
        expect(@cap.dump).to receive(:run_remote).with("cd #{@remote_path}; /custom/rake -s dump:restore PROGRESS_TTY\\=\\+ RAILS_ENV\\=production")
        @cap.find_and_execute_task('dump:remote:restore')
      end
    end

    describe 'download' do
      it 'runs rake versions to get avaliable versions' do
        expect(@cap.dump).to receive(:run_remote).with("cd #{@remote_path}; rake -s dump:versions PROGRESS_TTY\\=\\+ RAILS_ENV\\=production").and_return('')
        @cap.find_and_execute_task('dump:remote:download')
      end

      it 'blocks sending summary to versions' do
        expect(@cap.dump).to receive(:run_remote).with("cd #{@remote_path}; rake -s dump:versions PROGRESS_TTY\\=\\+ RAILS_ENV\\=production").and_return('')
        Dump::Env::DICTIONARY[:summary].each do |name|
          Dump::Env.with_env name => 'true' do
            @cap.find_and_execute_task('dump:remote:download')
          end
        end
      end

      test_passing_environment_variables(:remote, :transfer, {
        :like => 'rake -s dump:versions LIKE\\=some\\ data PROGRESS_TTY\\=\\+ RAILS_ENV\\=production',
        :tags => 'rake -s dump:versions PROGRESS_TTY\\=\\+ RAILS_ENV\\=production TAGS\\=some\\ data',
        :summary => 'rake -s dump:versions PROGRESS_TTY\\=\\+ RAILS_ENV\\=production', # block sending summary to versions
        :transfer_via => 'rake -s dump:versions PROGRESS_TTY\\=\\+ RAILS_ENV\\=production', # tranfer_via is used internally
      }, :cap_task => 'dump:remote:download')

      it 'does not download anything if there are no versions avaliable' do
        allow(@cap.dump).to receive(:run_remote).and_return('')
        expect(@cap.dump).not_to receive(:do_transfer)
        @cap.find_and_execute_task('dump:remote:download')
      end

      it 'transfers latest version dump' do
        allow(@cap.dump).to receive(:run_remote).and_return("100.tgz\n200.tgz\n300.tgz\n")
        expect(@cap.dump).to receive(:do_transfer).with(:down, "#{@remote_path}/dump/300.tgz", 'dump/300.tgz')
        allow(FileUtils).to receive(:mkpath)
        @cap.find_and_execute_task('dump:remote:download')
      end

      it 'handles extra spaces around file names' do
        allow(@cap.dump).to receive(:run_remote).and_return("\r\n\r\n\r  100.tgz   \r\n\r\n\r  200.tgz   \r\n\r\n\r  300.tgz   \r\n\r\n\r  ")
        expect(@cap.dump).to receive(:do_transfer).with(:down, "#{@remote_path}/dump/300.tgz", 'dump/300.tgz')
        allow(FileUtils).to receive(:mkpath)
        @cap.find_and_execute_task('dump:remote:download')
      end

      it 'creates local dump dir' do
        allow(@cap.dump).to receive(:run_remote).and_return("100.tgz\n200.tgz\n300.tgz\n")
        allow(@cap.dump).to receive(:do_transfer)
        expect(FileUtils).to receive(:mkpath).with('dump')
        @cap.find_and_execute_task('dump:remote:download')
      end

      it 'runs rake versions use custom rake binary' do
        expect(@cap.dump).to receive(:fetch_rake).and_return('/custom/rake')
        expect(@cap.dump).to receive(:run_remote).with("cd #{@remote_path}; /custom/rake -s dump:versions PROGRESS_TTY\\=\\+ RAILS_ENV\\=production").and_return('')
        @cap.find_and_execute_task('dump:remote:download')
      end
    end
  end

  describe 'upload' do
    it 'calls local:upload' do
      expect(@cap.dump.local).to receive(:upload).and_return('')
      @cap.find_and_execute_task('dump:upload')
    end
  end

  describe 'download' do
    it 'calls remote:download' do
      expect(@cap.dump.remote).to receive(:download).and_return('')
      @cap.find_and_execute_task('dump:download')
    end
  end

  describe 'mirror' do
    {'up' => [:local, :remote], 'down' => [:remote, :local]}.each do |dir, way|
      src = way[0]
      dst = way[1]
      describe name do
        it 'creates auto-backup with tag auto-backup' do
          expect(@cap.dump.namespaces[dst]).to receive(:create){ expect(Dump::Env[:tags]).to eq('auto-backup'); '' }
          @cap.find_and_execute_task("dump:mirror:#{dir}")
        end

        it 'creates auto-backup with additional tag auto-backup' do
          expect(@cap.dump.namespaces[dst]).to receive(:create){ expect(Dump::Env[:tags]).to eq('auto-backup,photos'); '' }
          Dump::Env.with_env :tags => 'photos' do
            @cap.find_and_execute_task("dump:mirror:#{dir}")
          end
        end

        it 'does not call local:create if auto-backup fails' do
          allow(@cap.dump.namespaces[dst]).to receive(:create).and_return('')
          expect(@cap.dump.namespaces[src]).not_to receive(:create)
          @cap.find_and_execute_task("dump:mirror:#{dir}")
        end

        it "calls local:create if auto-backup succeedes with tags mirror and mirror-#{dir}" do
          allow(@cap.dump.namespaces[dst]).to receive(:create).and_return('123.tgz')
          expect(@cap.dump.namespaces[src]).to receive(:create){ expect(Dump::Env[:tags]).to eq('mirror'); '' }
          @cap.find_and_execute_task("dump:mirror:#{dir}")
        end

        it "calls local:create if auto-backup succeedes with additional tags mirror and mirror-#{dir}" do
          allow(@cap.dump.namespaces[dst]).to receive(:create).and_return('123.tgz')
          expect(@cap.dump.namespaces[src]).to receive(:create){ expect(Dump::Env[:tags]).to eq('mirror,photos'); '' }
          Dump::Env.with_env :tags => 'photos' do
            @cap.find_and_execute_task("dump:mirror:#{dir}")
          end
        end

        it 'does not call local:upload or remote:restore if local:create fails' do
          allow(@cap.dump.namespaces[dst]).to receive(:create).and_return('123.tgz')
          allow(@cap.dump.namespaces[src]).to receive(:create).and_return('')
          expect(@cap.dump.namespaces[src]).not_to receive(:upload)
          expect(@cap.dump.namespaces[dst]).not_to receive(:restore)
          @cap.find_and_execute_task("dump:mirror:#{dir}")
        end

        it 'calls local:upload and remote:restore with only varibale ver set to file name if local:create returns file name' do
          allow(@cap.dump.namespaces[dst]).to receive(:create).and_return('123.tgz')
          allow(@cap.dump.namespaces[src]).to receive(:create).and_return('123.tgz')
          test_env = proc do
            expect(Dump::Env[:like]).to eq('123.tgz')
            expect(Dump::Env[:tags]).to eq(nil)
            expect(Dump::Env[:desc]).to eq(nil)
          end
          expect(@cap.dump.namespaces[src]).to receive(:"#{dir}load").ordered(&test_env)
          expect(@cap.dump.namespaces[dst]).to receive(:restore).ordered(&test_env)
          Dump::Env.with_env all_dictionary_variables do
            @cap.find_and_execute_task("dump:mirror:#{dir}")
          end
        end
      end
    end
  end

  describe 'backup' do
    it 'calls remote:create' do
      expect(@cap.dump.remote).to receive(:create).and_return('')
      @cap.find_and_execute_task('dump:backup')
    end

    it 'does not call remote:download if remote:create returns blank' do
      allow(@cap.dump.remote).to receive(:create).and_return('')
      expect(@cap.dump.remote).not_to receive(:download)
      @cap.find_and_execute_task('dump:backup')
    end

    it 'calls remote:download if remote:create returns file name' do
      allow(@cap.dump.remote).to receive(:create).and_return('123.tgz')
      expect(@cap.dump.remote).to receive(:download).ordered
      @cap.find_and_execute_task('dump:backup')
    end

    it 'calls remote:create with tag backup' do
      expect(@cap.dump.remote).to receive(:create) do
        expect(Dump::Env[:tags]).to eq('backup')
        ''
      end
      @cap.find_and_execute_task('dump:backup')
    end

    it 'calls remote:create with additional tag backup' do
      expect(@cap.dump.remote).to receive(:create) do
        expect(Dump::Env[:tags]).to eq('backup,photos')
        ''
      end
      Dump::Env.with_env :tags => 'photos' do
        @cap.find_and_execute_task('dump:backup')
      end
    end

    it 'passes description if it is set' do
      expect(@cap.dump.remote).to receive(:create) do
        expect(Dump::Env[:desc]).to eq('remote dump')
        ''
      end
      Dump::Env.with_env :desc => 'remote dump' do
        @cap.find_and_execute_task('dump:backup')
      end
    end

    it 'sends only ver variable' do
      allow(@cap.dump.remote).to receive(:create).and_return('123.tgz')
      expect(@cap.dump.remote).to receive(:download) do
        expect(Dump::Env[:like]).to eq('123.tgz')
        expect(Dump::Env[:tags]).to eq(nil)
        expect(Dump::Env[:desc]).to eq(nil)
        ''
      end
      Dump::Env.with_env all_dictionary_variables do
        @cap.find_and_execute_task('dump:backup')
      end
    end
  end
end
