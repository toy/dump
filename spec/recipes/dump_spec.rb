require File.dirname(__FILE__) + '/../spec_helper'
require 'capistrano'

describe "cap dump" do
  before do
    @cap = Capistrano::Configuration.new
    @cap.load File.dirname(__FILE__) + '/../../recipes/dump.rb'
    @remote_path = "/home/test/apps/dummy"
    @cap.set(:current_path, @remote_path)
  end

  describe "local" do
    describe "versions" do
      it "should call local rake task" do
        @cap.should_receive(:run_local).with("rake -s dump:versions").and_return('')
        @cap.find_and_execute_task("dump:local:versions")
      end

      %w(VER VERSION).each do |name|
        it "should pass version if it is set through environment variable #{name}" do
          @cap.should_receive(:run_local).with("rake -s dump:versions VER=\"21376\"").and_return('')
          with_env name, '21376' do
            @cap.find_and_execute_task("dump:local:versions")
          end
        end
      end

      it "should print result of rake task" do
        @cap.stub!(:run_local).and_return("123123.tgz\n")
        grab_output{
          @cap.find_and_execute_task("dump:local:versions")
        }.should == "123123.tgz\n"
      end
    end

    describe "create" do
      it "should raise if dump creation fails" do
        @cap.should_receive(:run_local).with("rake -s dump:create DESC=\"local\"").and_return('')
        proc{
          @cap.find_and_execute_task("dump:local:create")
        }.should raise_error('Failed creating dump')
      end

      it "should call local rake task with default DESC local" do
        @cap.should_receive(:run_local).with("rake -s dump:create DESC=\"local\"").and_return('123.tgz')
        grab_output{
          @cap.find_and_execute_task("dump:local:create")
        }
      end

      %w(DESC DESCRIPTION).each do |name|
        it "should pass description if it is set through environment variable #{name}" do
          @cap.should_receive(:run_local).with("rake -s dump:create DESC=\"local dump\"").and_return('123.tgz')
          with_env name, 'local dump' do
            grab_output{
              @cap.find_and_execute_task("dump:local:create")
            }
          end
        end
      end

      it "should print result of rake task" do
        @cap.stub!(:run_local).and_return("123123.tgz\n")
        grab_output{
          @cap.find_and_execute_task("dump:local:create")
        }.should == "123123.tgz\n"
      end

      it "should return stripped result of rake task" do
        @cap.stub!(:run_local).and_return("123123.tgz\n")
        grab_output{
          @cap.find_and_execute_task("dump:local:create").should == "123123.tgz"
        }
      end
    end

    describe "restore" do
      it "should call local rake task" do
        @cap.should_receive(:run_local).with("rake -s dump:restore")
        @cap.find_and_execute_task("dump:local:restore")
      end

      %w(VER VERSION).each do |name|
        it "should pass version if it is set through environment variable #{name}" do
          @cap.should_receive(:run_local).with("rake -s dump:restore VER=\"21376\"")
          with_env name, '21376' do
            @cap.find_and_execute_task("dump:local:restore")
          end
        end
      end
    end

    describe "upload" do
      it "should run rake versions to get avaliable versions" do
        @cap.should_receive(:run_local).with("rake -s dump:versions").and_return('')
        @cap.find_and_execute_task("dump:local:upload")
      end

      %w(VER VERSION).each do |name|
        it "should pass version if it is set through environment variable #{name}" do
          @cap.should_receive(:run_local).with("rake -s dump:versions VER=\"21376\"").and_return('')
          with_env name, '21376' do
            @cap.find_and_execute_task("dump:local:upload")
          end
        end
      end

      it "should not upload anything if there are no versions avaliable" do
        @cap.stub!(:run_local).and_return('')
        @cap.should_not_receive(:transfer)
        @cap.find_and_execute_task("dump:local:upload")
      end

      it "should transfer latest version dump" do
        @cap.stub!(:run_local).and_return("100.tgz\n200.tgz\n300.tgz\n")
        @cap.should_receive(:transfer).with(:up, "dump/300.tgz", "#{@remote_path}/dump/300.tgz", :via => :scp)
        @cap.find_and_execute_task("dump:local:upload")
      end
    end
  end

  describe "remote" do
    describe "versions" do
      it "should call remote rake task" do
        @cap.should_receive(:capture).with("cd #{@remote_path}; rake -s dump:versions").and_return('')
        @cap.find_and_execute_task("dump:remote:versions")
      end

      %w(VER VERSION).each do |name|
        it "should pass version if it is set through environment variable #{name}" do
          @cap.should_receive(:capture).with("cd #{@remote_path}; rake -s dump:versions VER=\"21376\"").and_return('')
          with_env name, '21376' do
            @cap.find_and_execute_task("dump:remote:versions")
          end
        end
      end

      it "should print result of rake task" do
        @cap.stub!(:capture).and_return("123123.tgz\n")
        grab_output{
          @cap.find_and_execute_task("dump:remote:versions")
        }.should == "123123.tgz\n"
      end
    end

    describe "create" do
      it "should raise if dump creation fails" do
        @cap.should_receive(:capture).with("cd #{@remote_path}; rake -s dump:create RAILS_ENV=\"production\" DESC=\"remote\"").and_return('')
        proc{
          @cap.find_and_execute_task("dump:remote:create")
        }.should raise_error('Failed creating dump')
      end

      it "should call remote rake task with default rails_env and default DESC remote" do
        @cap.should_receive(:capture).with("cd #{@remote_path}; rake -s dump:create RAILS_ENV=\"production\" DESC=\"remote\"").and_return('123.tgz')
        grab_output{
          @cap.find_and_execute_task("dump:remote:create")
        }
      end

      it "should call remote rake task with fetched rails_env and default DESC remote" do
        @cap.dump.should_receive(:fetch_rails_env).and_return('dev')
        @cap.should_receive(:capture).with("cd #{@remote_path}; rake -s dump:create RAILS_ENV=\"dev\" DESC=\"remote\"").and_return('123.tgz')
        grab_output{
          @cap.find_and_execute_task("dump:remote:create")
        }
      end

      %w(DESC DESCRIPTION).each do |name|
        it "should pass description if it is set through environment variable #{name}" do
          @cap.should_receive(:capture).with("cd #{@remote_path}; rake -s dump:create RAILS_ENV=\"production\" DESC=\"remote dump\"").and_return('123.tgz')
          with_env name, 'remote dump' do
            grab_output{
              @cap.find_and_execute_task("dump:remote:create")
            }
          end
        end
      end

      it "should print result of rake task" do
        @cap.stub!(:capture).and_return("123123.tgz\n")
        grab_output{
          @cap.find_and_execute_task("dump:remote:create")
        }.should == "123123.tgz\n"
      end

      it "should return stripped result of rake task" do
        @cap.stub!(:capture).and_return("123123.tgz\n")
        grab_output{
          @cap.find_and_execute_task("dump:remote:create").should == "123123.tgz"
        }
      end
    end

    describe "restore" do
      it "should call remote rake task with default rails_env" do
        @cap.should_receive(:run).with("cd #{@remote_path}; rake -s dump:restore RAILS_ENV=\"production\"")
        @cap.find_and_execute_task("dump:remote:restore")
      end

      it "should call remote rake task with fetched rails_env" do
        @cap.dump.should_receive(:fetch_rails_env).and_return('dev')
        @cap.should_receive(:run).with("cd #{@remote_path}; rake -s dump:restore RAILS_ENV=\"dev\"")
        @cap.find_and_execute_task("dump:remote:restore")
      end


      %w(VER VERSION).each do |name|
        it "should pass version if it is set through environment variable #{name}" do
          @cap.should_receive(:run).with("cd #{@remote_path}; rake -s dump:restore RAILS_ENV=\"production\" VER=\"21376\"")
          with_env name, '21376' do
            @cap.find_and_execute_task("dump:remote:restore")
          end
        end
      end
    end

    describe "download" do
      it "should run rake versions to get avaliable versions" do
        @cap.should_receive(:capture).with("cd #{@remote_path}; rake -s dump:versions").and_return('')
        @cap.find_and_execute_task("dump:remote:download")
      end

      %w(VER VERSION).each do |name|
        it "should pass version if it is set through environment variable #{name}" do
          @cap.should_receive(:capture).with("cd #{@remote_path}; rake -s dump:versions VER=\"21376\"").and_return('')
          with_env name, '21376' do
            @cap.find_and_execute_task("dump:remote:download")
          end
        end
      end

      it "should not download anything if there are no versions avaliable" do
        @cap.stub!(:capture).and_return('')
        @cap.should_not_receive(:transfer)
        @cap.find_and_execute_task("dump:remote:download")
      end

      it "should transfer latest version dump" do
        @cap.stub!(:capture).and_return("100.tgz\n200.tgz\n300.tgz\n")
        @cap.should_receive(:transfer).with(:down, "#{@remote_path}/dump/300.tgz", "dump/300.tgz", :via => :scp)
        FileUtils.stub!(:mkpath)
        @cap.find_and_execute_task("dump:remote:download")
      end

      it "should create local dump dir" do
        @cap.stub!(:capture).and_return("100.tgz\n200.tgz\n300.tgz\n")
        @cap.stub!(:transfer)
        FileUtils.should_receive(:mkpath).with('dump')
        @cap.find_and_execute_task("dump:remote:download")
      end
    end
  end

  describe "mirror" do
    {"up" => [:local, :remote], "down" => [:remote, :local]}.each do |dir, way|
      src = way[0]
      dst = way[1]
      describe name do
        it "should create auto-backup" do
          @cap.dump.namespaces[dst].should_receive(:create){ ENV['DESC'].should == 'auto-backup'; '' }
          @cap.find_and_execute_task("dump:mirror:#{dir}")
        end

        it "should not call local:create if auto-backup fails" do
          @cap.dump.namespaces[dst].stub!(:create).and_return('')
          @cap.dump.namespaces[src].should_not_receive(:create)
          @cap.find_and_execute_task("dump:mirror:#{dir}")
        end

        it "should call local:create if auto-backup succeedes" do
          @cap.dump.namespaces[dst].stub!(:create).and_return('123.tgz')
          @cap.dump.namespaces[src].should_receive(:create){ ENV['DESC'].should == "mirror:#{dir}"; '' }
          @cap.find_and_execute_task("dump:mirror:#{dir}")
        end

        it "should not call local:upload or remote:restore if local:create fails" do
          @cap.dump.namespaces[dst].stub!(:create).and_return('123.tgz')
          @cap.dump.namespaces[src].stub!(:create).and_return('')
          @cap.dump.namespaces[src].should_not_receive(:upload)
          @cap.dump.namespaces[dst].should_not_receive(:restore)
          @cap.find_and_execute_task("dump:mirror:#{dir}")
        end

        it "should call local:upload and remote:restore with VER set to file name if local:create returns file name" do
          @cap.dump.namespaces[dst].stub!(:create).and_return('123.tgz')
          @cap.dump.namespaces[src].stub!(:create).and_return('123.tgz')
          @cap.dump.namespaces[src].should_receive(:"#{dir}load").ordered{ ENV['VER'].should == '123.tgz' }
          @cap.dump.namespaces[dst].should_receive(:restore).ordered{ ENV['VER'].should == '123.tgz' }
          @cap.find_and_execute_task("dump:mirror:#{dir}")
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

    it "should call remote:create with desc backup by default" do
      def (@cap.dump.remote).create
        ENV['DESC'].should == 'backup'
        ''
      end
      @cap.find_and_execute_task("dump:backup")
    end

    it "should pass description if it is set through environment variable DESC" do
      def (@cap.dump.remote).create
        ENV['DESC'].should == 'remote dump'
        ENV['DESCRIPTION'].should == nil
        ''
      end
      with_env 'DESC', 'remote dump' do
        @cap.find_and_execute_task("dump:backup")
      end
    end

    it "should pass description if it is set through environment variable DESCRIPTION" do
      def (@cap.dump.remote).create
        ENV['DESC'].should == nil
        ENV['DESCRIPTION'].should == 'remote dump'
        ''
      end
      with_env 'DESCRIPTION', 'remote dump' do
        @cap.find_and_execute_task("dump:backup")
      end
    end
  end
end
