require File.dirname(__FILE__) + '/../spec_helper'
require 'capistrano'

describe "cap dump" do
  before do
    @cap = Capistrano::Configuration.new
    @cap.load File.dirname(__FILE__) + '/../../recipes/dump.rb'
    @remote_path = "/home/test/apps/dummy"
    @cap.set(:current_path, @remote_path)
  end

  def all_dictionary_variables
    DumpRake::Env.dictionary.each_with_object({}) do |(key, value), filled_env|
      filled_env[key] = value.join(' ')
    end
  end

  def self.test_passing_environment_variables(place, command, command_strings, options = {})
    DumpRake::Env.variable_names_for_command(command).each do |variable|
      command_string = command_strings[variable]
      DumpRake::Env.dictionary[variable].each do |name|
        it "should pass #{variable} if it is set through environment variable #{name}" do
          violated "command_string not specified" unless command_string
          full_command_string = command_string
          full_command_string = "cd #{@remote_path}; #{command_string}" if place == :remote
          @cap.dump.should_receive(:"run_#{place}").with(full_command_string).and_return(options[:return_value] || '')
          DumpRake::Env.with_env name => options[:value] || 'some data' do
            cap_task = options[:cap_task] || "dump:#{place}:#{command}"
            grab_output{ @cap.find_and_execute_task(cap_task) }
          end
        end
      end
    end
  end

  describe "local" do
    describe "versions" do
      it "should call local rake task" do
        @cap.dump.should_receive(:run_local).with("rake -s dump:versions").and_return('')
        @cap.find_and_execute_task("dump:local:versions")
      end

      test_passing_environment_variables(:local, :versions, {
        :like => "rake -s dump:versions 'LIKE=some data'",
        :tags => "rake -s dump:versions 'TAGS=some data'",
        :summary => "rake -s dump:versions 'SUMMARY=some data'",
      })

      it "should print result of rake task" do
        @cap.dump.stub!(:run_local).and_return("123123.tgz\n")
        grab_output{
          @cap.find_and_execute_task("dump:local:versions")
        }[:stdout].should == "123123.tgz\n"
      end
    end

    describe "cleanup" do
      it "should call local rake task" do
        @cap.dump.should_receive(:run_local).with("rake -s dump:cleanup").and_return('')
        @cap.find_and_execute_task("dump:local:cleanup")
      end

      test_passing_environment_variables(:local, :cleanup, {
        :like => "rake -s dump:cleanup 'LIKE=some data'",
        :tags => "rake -s dump:cleanup 'TAGS=some data'",
        :leave => "rake -s dump:cleanup 'LEAVE=some data'",
      })

      it "should print result of rake task" do
        @cap.dump.stub!(:run_local).and_return("123123.tgz\n")
        grab_output{
          @cap.find_and_execute_task("dump:local:cleanup")
        }[:stdout].should == "123123.tgz\n"
      end
    end

    describe "create" do
      it "should raise if dump creation fails" do
        @cap.dump.should_receive(:run_local).with("rake -s dump:create TAGS=local").and_return('')
        proc{
          @cap.find_and_execute_task("dump:local:create")
        }.should raise_error('Failed creating dump')
      end

      it "should call local rake task with tag local" do
        @cap.dump.should_receive(:run_local).with("rake -s dump:create TAGS=local").and_return('123.tgz')
        grab_output{
          @cap.find_and_execute_task("dump:local:create")
        }
      end

      it "should call local rake task with additional tag local" do
        @cap.dump.should_receive(:run_local).with("rake -s dump:create TAGS=local,photos").and_return('123.tgz')
        grab_output{
          DumpRake::Env.with_env :tags => 'photos' do
            @cap.find_and_execute_task("dump:local:create")
          end
        }
      end

      test_passing_environment_variables(:local, :create, {
        :desc => "rake -s dump:create 'DESC=some data' TAGS=local",
        :tags => "rake -s dump:create 'TAGS=local,some data'",
        :assets => "rake -s dump:create 'ASSETS=some data' TAGS=local",
        :tables => "rake -s dump:create 'TABLES=some data' TAGS=local",
      }, :return_value => '123.tgz')

      it "should print result of rake task" do
        @cap.dump.stub!(:run_local).and_return("123123.tgz\n")
        grab_output{
          @cap.find_and_execute_task("dump:local:create")
        }[:stdout].should == "123123.tgz\n"
      end

      it "should return stripped result of rake task" do
        @cap.dump.stub!(:run_local).and_return("123123.tgz\n")
        grab_output{
          @cap.find_and_execute_task("dump:local:create").should == "123123.tgz"
        }
      end
    end

    describe "restore" do
      it "should call local rake task" do
        @cap.dump.should_receive(:run_local).with("rake -s dump:restore")
        @cap.find_and_execute_task("dump:local:restore")
      end

      test_passing_environment_variables(:local, :restore, {
        :like => "rake -s dump:restore 'LIKE=some data'",
        :tags => "rake -s dump:restore 'TAGS=some data'",
      })
    end

    describe "upload" do
      it "should run rake versions to get avaliable versions" do
        @cap.dump.should_receive(:run_local).with("rake -s dump:versions").and_return('')
        @cap.find_and_execute_task("dump:local:upload")
      end

      test_passing_environment_variables(:local, :versions, {
        :like => "rake -s dump:versions 'LIKE=some data'",
        :tags => "rake -s dump:versions 'TAGS=some data'",
        :summary => "rake -s dump:versions", # block sending summary to versions
      }, :cap_task => 'dump:local:upload')

      it "should not upload anything if there are no versions avaliable" do
        @cap.dump.stub!(:run_local).and_return('')
        @cap.should_not_receive(:transfer)
        @cap.find_and_execute_task("dump:local:upload")
      end

      it "should transfer latest version dump" do
        @cap.dump.stub!(:run_local).and_return("100.tgz\n200.tgz\n300.tgz\n")
        @cap.should_receive(:transfer).with(:up, "dump/300.tgz", "#{@remote_path}/dump/300.tgz", :via => :scp)
        @cap.find_and_execute_task("dump:local:upload")
      end

      it "should handle extra spaces around file names" do
        @cap.dump.stub!(:run_local).and_return("\r\n\r\n\r  100.tgz   \r\n\r\n\r  200.tgz   \r\n\r\n\r  300.tgz   \r\n\r\n\r  ")
        @cap.should_receive(:transfer).with(:up, "dump/300.tgz", "#{@remote_path}/dump/300.tgz", :via => :scp)
        @cap.find_and_execute_task("dump:local:upload")
      end
    end
  end

  describe "remote" do
    describe "versions" do
      it "should call remote rake task" do
        @cap.dump.should_receive(:run_remote).with("cd #{@remote_path}; rake -s dump:versions PROGRESS_TTY=+ RAILS_ENV=production").and_return('')
        @cap.find_and_execute_task("dump:remote:versions")
      end

      test_passing_environment_variables(:remote, :versions, {
        :like => "rake -s dump:versions 'LIKE=some data' PROGRESS_TTY=+ RAILS_ENV=production",
        :tags => "rake -s dump:versions PROGRESS_TTY=+ RAILS_ENV=production 'TAGS=some data'",
        :summary => "rake -s dump:versions PROGRESS_TTY=+ RAILS_ENV=production 'SUMMARY=some data'",
      })

      it "should print result of rake task" do
        @cap.dump.stub!(:run_remote).and_return("123123.tgz\n")
        grab_output{
          @cap.find_and_execute_task("dump:remote:versions")
        }[:stdout].should == "123123.tgz\n"
      end

      it "should use custom rake binary" do
        @cap.dump.should_receive(:fetch_rake).and_return('/custom/rake')
        @cap.dump.should_receive(:run_remote).with("cd #{@remote_path}; /custom/rake -s dump:versions PROGRESS_TTY=+ RAILS_ENV=production").and_return('')
        @cap.find_and_execute_task("dump:remote:versions")
      end
    end

    describe "cleanup" do
      it "should call remote rake task" do
        @cap.dump.should_receive(:run_remote).with("cd #{@remote_path}; rake -s dump:cleanup PROGRESS_TTY=+ RAILS_ENV=production").and_return('')
        @cap.find_and_execute_task("dump:remote:cleanup")
      end

      test_passing_environment_variables(:remote, :cleanup, {
        :like => "rake -s dump:cleanup 'LIKE=some data' PROGRESS_TTY=+ RAILS_ENV=production",
        :tags => "rake -s dump:cleanup PROGRESS_TTY=+ RAILS_ENV=production 'TAGS=some data'",
        :leave => "rake -s dump:cleanup 'LEAVE=some data' PROGRESS_TTY=+ RAILS_ENV=production",
      })

      it "should print result of rake task" do
        @cap.dump.stub!(:run_remote).and_return("123123.tgz\n")
        grab_output{
          @cap.find_and_execute_task("dump:remote:cleanup")
        }[:stdout].should == "123123.tgz\n"
      end

      it "should use custom rake binary" do
        @cap.dump.should_receive(:fetch_rake).and_return('/custom/rake')
        @cap.dump.should_receive(:run_remote).with("cd #{@remote_path}; /custom/rake -s dump:cleanup PROGRESS_TTY=+ RAILS_ENV=production").and_return('')
        @cap.find_and_execute_task("dump:remote:cleanup")
      end
    end

    describe "create" do
      it "should raise if dump creation fails" do
        @cap.dump.should_receive(:run_remote).with("cd #{@remote_path}; rake -s dump:create PROGRESS_TTY=+ RAILS_ENV=production TAGS=remote").and_return('')
        proc{
          @cap.find_and_execute_task("dump:remote:create")
        }.should raise_error('Failed creating dump')
      end

      it "should call remote rake task with default rails_env and tag remote" do
        @cap.dump.should_receive(:run_remote).with("cd #{@remote_path}; rake -s dump:create PROGRESS_TTY=+ RAILS_ENV=production TAGS=remote").and_return('123.tgz')
        grab_output{
          @cap.find_and_execute_task("dump:remote:create")
        }
      end

      it "should call remote rake task with default rails_env and additional tag remote" do
        @cap.dump.should_receive(:run_remote).with("cd #{@remote_path}; rake -s dump:create PROGRESS_TTY=+ RAILS_ENV=production TAGS=remote,photos").and_return('123.tgz')
        grab_output{
          DumpRake::Env.with_env :tags => 'photos' do
            @cap.find_and_execute_task("dump:remote:create")
          end
        }
      end

      it "should call remote rake task with fetched rails_env and default DESC remote" do
        @cap.dump.should_receive(:fetch_rails_env).and_return('dev')
        @cap.dump.should_receive(:run_remote).with("cd #{@remote_path}; rake -s dump:create PROGRESS_TTY=+ RAILS_ENV=dev TAGS=remote").and_return('123.tgz')
        grab_output{
          @cap.find_and_execute_task("dump:remote:create")
        }
      end

      test_passing_environment_variables(:remote, :create, {
        :desc => "rake -s dump:create 'DESC=some data' PROGRESS_TTY=+ RAILS_ENV=production TAGS=remote",
        :tags => "rake -s dump:create PROGRESS_TTY=+ RAILS_ENV=production 'TAGS=remote,some data'",
        :assets => "rake -s dump:create 'ASSETS=some data' PROGRESS_TTY=+ RAILS_ENV=production TAGS=remote",
        :tables => "rake -s dump:create PROGRESS_TTY=+ RAILS_ENV=production 'TABLES=some data' TAGS=remote",
      }, :return_value => '123.tgz')

      it "should print result of rake task" do
        @cap.dump.stub!(:run_remote).and_return("123123.tgz\n")
        grab_output{
          @cap.find_and_execute_task("dump:remote:create")
        }[:stdout].should == "123123.tgz\n"
      end

      it "should return stripped result of rake task" do
        @cap.dump.stub!(:run_remote).and_return("123123.tgz\n")
        grab_output{
          @cap.find_and_execute_task("dump:remote:create").should == "123123.tgz"
        }
      end

      it "should use custom rake binary" do
        @cap.dump.should_receive(:fetch_rake).and_return('/custom/rake')
        @cap.dump.should_receive(:run_remote).with("cd #{@remote_path}; /custom/rake -s dump:create PROGRESS_TTY=+ RAILS_ENV=production TAGS=remote").and_return('123.tgz')
        grab_output{
          @cap.find_and_execute_task("dump:remote:create")
        }
      end
    end

    describe "restore" do
      it "should call remote rake task with default rails_env" do
        @cap.dump.should_receive(:run_remote).with("cd #{@remote_path}; rake -s dump:restore PROGRESS_TTY=+ RAILS_ENV=production")
        @cap.find_and_execute_task("dump:remote:restore")
      end

      it "should call remote rake task with fetched rails_env" do
        @cap.dump.should_receive(:fetch_rails_env).and_return('dev')
        @cap.dump.should_receive(:run_remote).with("cd #{@remote_path}; rake -s dump:restore PROGRESS_TTY=+ RAILS_ENV=dev")
        @cap.find_and_execute_task("dump:remote:restore")
      end

      test_passing_environment_variables(:remote, :restore, {
        :like => "rake -s dump:restore 'LIKE=some data' PROGRESS_TTY=+ RAILS_ENV=production",
        :tags => "rake -s dump:restore PROGRESS_TTY=+ RAILS_ENV=production 'TAGS=some data'",
      })

      it "should use custom rake binary" do
        @cap.dump.should_receive(:fetch_rake).and_return('/custom/rake')
        @cap.dump.should_receive(:run_remote).with("cd #{@remote_path}; /custom/rake -s dump:restore PROGRESS_TTY=+ RAILS_ENV=production")
        @cap.find_and_execute_task("dump:remote:restore")
      end
    end

    describe "download" do
      it "should run rake versions to get avaliable versions" do
        @cap.dump.should_receive(:run_remote).with("cd #{@remote_path}; rake -s dump:versions PROGRESS_TTY=+ RAILS_ENV=production").and_return('')
        @cap.find_and_execute_task("dump:remote:download")
      end

      it "should block sending summary to versions" do
        @cap.dump.should_receive(:run_remote).with("cd #{@remote_path}; rake -s dump:versions PROGRESS_TTY=+ RAILS_ENV=production").and_return('')
        DumpRake::Env.dictionary[:summary].each do |name|
          DumpRake::Env.with_env name => 'true' do
            @cap.find_and_execute_task("dump:remote:download")
          end
        end
      end

      test_passing_environment_variables(:remote, :download, {
        :like => "rake -s dump:versions 'LIKE=some data' PROGRESS_TTY=+ RAILS_ENV=production",
        :tags => "rake -s dump:versions PROGRESS_TTY=+ RAILS_ENV=production 'TAGS=some data'",
        :summary => "rake -s dump:versions PROGRESS_TTY=+ RAILS_ENV=production", # block sending summary to versions
      }, :cap_task => "dump:remote:download")

      it "should not download anything if there are no versions avaliable" do
        @cap.dump.stub!(:run_remote).and_return('')
        @cap.should_not_receive(:transfer)
        @cap.find_and_execute_task("dump:remote:download")
      end

      it "should transfer latest version dump" do
        @cap.dump.stub!(:run_remote).and_return("100.tgz\n200.tgz\n300.tgz\n")
        @cap.should_receive(:transfer).with(:down, "#{@remote_path}/dump/300.tgz", "dump/300.tgz", :via => :scp)
        FileUtils.stub!(:mkpath)
        @cap.find_and_execute_task("dump:remote:download")
      end

      it "should handle extra spaces around file names" do
        @cap.dump.stub!(:run_remote).and_return("\r\n\r\n\r  100.tgz   \r\n\r\n\r  200.tgz   \r\n\r\n\r  300.tgz   \r\n\r\n\r  ")
        @cap.should_receive(:transfer).with(:down, "#{@remote_path}/dump/300.tgz", "dump/300.tgz", :via => :scp)
        FileUtils.stub!(:mkpath)
        @cap.find_and_execute_task("dump:remote:download")
      end

      it "should create local dump dir" do
        @cap.dump.stub!(:run_remote).and_return("100.tgz\n200.tgz\n300.tgz\n")
        @cap.stub!(:transfer)
        FileUtils.should_receive(:mkpath).with('dump')
        @cap.find_and_execute_task("dump:remote:download")
      end

      it "should run rake versions use custom rake binary" do
        @cap.dump.should_receive(:fetch_rake).and_return('/custom/rake')
        @cap.dump.should_receive(:run_remote).with("cd #{@remote_path}; /custom/rake -s dump:versions PROGRESS_TTY=+ RAILS_ENV=production").and_return('')
        @cap.find_and_execute_task("dump:remote:download")
      end
    end
  end

  describe "mirror" do
    {"up" => [:local, :remote], "down" => [:remote, :local]}.each do |dir, way|
      src = way[0]
      dst = way[1]
      describe name do
        it "should create auto-backup with tag auto-backup" do
          @cap.dump.namespaces[dst].should_receive(:create){ DumpRake::Env[:tags].should == 'auto-backup'; '' }
          @cap.find_and_execute_task("dump:mirror:#{dir}")
        end

        it "should create auto-backup with additional tag auto-backup" do
          @cap.dump.namespaces[dst].should_receive(:create){ DumpRake::Env[:tags].should == 'auto-backup,photos'; '' }
          DumpRake::Env.with_env :tags => 'photos' do
            @cap.find_and_execute_task("dump:mirror:#{dir}")
          end
        end

        it "should not call local:create if auto-backup fails" do
          @cap.dump.namespaces[dst].stub!(:create).and_return('')
          @cap.dump.namespaces[src].should_not_receive(:create)
          @cap.find_and_execute_task("dump:mirror:#{dir}")
        end

        it "should call local:create if auto-backup succeedes with tags mirror and mirror-#{dir}" do
          @cap.dump.namespaces[dst].stub!(:create).and_return('123.tgz')
          @cap.dump.namespaces[src].should_receive(:create){ DumpRake::Env[:tags].should == "mirror,mirror-#{dir}"; '' }
          @cap.find_and_execute_task("dump:mirror:#{dir}")
        end

        it "should call local:create if auto-backup succeedes with additional tags mirror and mirror-#{dir}" do
          @cap.dump.namespaces[dst].stub!(:create).and_return('123.tgz')
          @cap.dump.namespaces[src].should_receive(:create){ DumpRake::Env[:tags].should == "mirror,mirror-#{dir},photos"; '' }
          DumpRake::Env.with_env :tags => 'photos' do
            @cap.find_and_execute_task("dump:mirror:#{dir}")
          end
        end

        it "should not call local:upload or remote:restore if local:create fails" do
          @cap.dump.namespaces[dst].stub!(:create).and_return('123.tgz')
          @cap.dump.namespaces[src].stub!(:create).and_return('')
          @cap.dump.namespaces[src].should_not_receive(:upload)
          @cap.dump.namespaces[dst].should_not_receive(:restore)
          @cap.find_and_execute_task("dump:mirror:#{dir}")
        end

        it "should call local:upload and remote:restore with only varibale ver set to file name if local:create returns file name" do
          @cap.dump.namespaces[dst].stub!(:create).and_return('123.tgz')
          @cap.dump.namespaces[src].stub!(:create).and_return('123.tgz')
          test_env = proc{
            DumpRake::Env[:like].should == '123.tgz'
            DumpRake::Env[:tags].should == nil
            DumpRake::Env[:desc].should == nil
          }
          @cap.dump.namespaces[src].should_receive(:"#{dir}load").ordered(&test_env)
          @cap.dump.namespaces[dst].should_receive(:restore).ordered(&test_env)
          DumpRake::Env.with_env all_dictionary_variables do
            @cap.find_and_execute_task("dump:mirror:#{dir}")
          end
        end
      end
    end
  end

  describe "backup" do
    it "should call remote:create" do
      @cap.dump.remote.should_receive(:create).and_return('')
      @cap.find_and_execute_task("dump:backup")
    end

    it "should not call remote:download if remote:create returns blank" do
      @cap.dump.remote.stub!(:create).and_return('')
      @cap.dump.remote.should_not_receive(:download)
      @cap.find_and_execute_task("dump:backup")
    end

    it "should call remote:download if remote:create returns file name" do
      @cap.dump.remote.stub!(:create).and_return('123.tgz')
      @cap.dump.remote.should_receive(:download).ordered
      @cap.find_and_execute_task("dump:backup")
    end

    it "should call remote:create with tag backup" do
      def (@cap.dump.remote).create
        DumpRake::Env[:tags].should == 'backup'
        ''
      end
      @cap.find_and_execute_task("dump:backup")
    end

    it "should call remote:create with additional tag backup" do
      def (@cap.dump.remote).create
        DumpRake::Env[:tags].should == 'backup,photos'
        ''
      end
      DumpRake::Env.with_env :tags => 'photos' do
        @cap.find_and_execute_task("dump:backup")
      end
    end

    it "should pass description if it is set" do
      def (@cap.dump.remote).create
        DumpRake::Env[:desc].should == 'remote dump'
        ''
      end
      DumpRake::Env.with_env :desc => 'remote dump' do
        @cap.find_and_execute_task("dump:backup")
      end
    end

    it "should send only ver variable" do
      @cap.dump.remote.stub!(:create).and_return('123.tgz')
      def (@cap.dump.remote).download
        DumpRake::Env[:like].should == '123.tgz'
        DumpRake::Env[:tags].should == nil
        DumpRake::Env[:desc].should == nil
        ''
      end
      DumpRake::Env.with_env all_dictionary_variables do
        @cap.find_and_execute_task("dump:backup")
      end
    end
  end
end
