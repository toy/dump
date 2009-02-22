require File.dirname(__FILE__) + '/../spec_helper'
require 'capistrano'
require 'capistrano/cli'
require 'capistrano/cli'

def with_env(key, value)
  old_value, ENV[key] = ENV[key], value
  yield
ensure
  ENV[key] = old_value
end

def grab_output
  old_value, $stdout = $stdout, StringIO.new
  yield
  $stdout.string
ensure
  $stdout = old_value
end

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
      it "should call local rake task" do
        @cap.should_receive(:run_local).with("rake -s dump:create").and_return('')
        @cap.find_and_execute_task("dump:local:create")
      end
      
      %w(DESC DESCRIPTION).each do |name|
        it "should pass description if it is set through environment variable #{name}" do
          @cap.should_receive(:run_local).with("rake -s dump:create DESC=\"local dump\"").and_return('')
          with_env name, 'local dump' do
            @cap.find_and_execute_task("dump:local:create")
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
      it "should call remote rake task" do
        @cap.should_receive(:capture).with("cd #{@remote_path}; rake -s dump:create").and_return('')
        @cap.find_and_execute_task("dump:remote:create")
      end
  
      %w(DESC DESCRIPTION).each do |name|
        it "should pass description if it is set through environment variable #{name}" do
          @cap.should_receive(:capture).with("cd #{@remote_path}; rake -s dump:create DESC=\"remote dump\"").and_return('')
          with_env name, 'remote dump' do
            @cap.find_and_execute_task("dump:remote:create")
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
      it "should call remote rake task" do
        @cap.should_receive(:run).with("cd #{@remote_path}; rake -s dump:restore")
        @cap.find_and_execute_task("dump:remote:restore")
      end
  
      %w(VER VERSION).each do |name|
        it "should pass version if it is set through environment variable #{name}" do
          @cap.should_receive(:run).with("cd #{@remote_path}; rake -s dump:restore VER=\"21376\"")
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
        @cap.find_and_execute_task("dump:remote:download")
      end
    end
  end
  
  describe "mirror" do
    describe "up" do
      it "should call local:create" do
        @cap.dump.local.should_receive(:create).and_return('')
        @cap.find_and_execute_task("dump:mirror:up")
      end
  
      it "should not call local:upload or remote:restore if local:create returns blank" do
        @cap.dump.local.stub!(:create).and_return('')
        @cap.dump.local.should_not_receive(:upload)
        @cap.dump.remote.should_not_receive(:restore)
        @cap.find_and_execute_task("dump:mirror:up")
      end
  
      it "should call local:upload and remote:restore if local:create returns file name" do
        @cap.dump.local.stub!(:create).and_return('123.tgz')
        @cap.dump.local.should_receive(:upload)
        @cap.dump.remote.should_receive(:restore)
        @cap.find_and_execute_task("dump:mirror:up")
      end
  
      it "should call local:upload and remote:restore with environment variable VER set to name of created file" do
        @cap.dump.local.stub!(:create).and_return('123.tgz')
        def (@cap.dump.local).upload
          ENV['VER'].should == '123.tgz'
        end
        def (@cap.dump.remote).restore
          ENV['VER'].should == '123.tgz'
        end
        @cap.find_and_execute_task("dump:mirror:up")
      end
    end
  
    describe "down" do
      it "should call remote:create" do
        @cap.dump.remote.should_receive(:create).and_return('')
        @cap.find_and_execute_task("dump:mirror:down")
      end
  
      it "should not call remote:download or local:restore if remote:create returns blank" do
        @cap.dump.remote.stub!(:create).and_return('')
        @cap.dump.remote.should_not_receive(:download)
        @cap.dump.local.should_not_receive(:restore)
        @cap.find_and_execute_task("dump:mirror:down")
      end
  
      it "should call remote:download and local:restore if remote:create returns file name" do
        @cap.dump.remote.stub!(:create).and_return('123.tgz')
        @cap.dump.remote.should_receive(:download)
        @cap.dump.local.should_receive(:restore)
        @cap.find_and_execute_task("dump:mirror:down")
      end
  
      it "should call remote:download and local:restore with environment variable VER set to name of created file" do
        @cap.dump.remote.stub!(:create).and_return('123.tgz')
        def (@cap.dump.remote).download
          ENV['VER'].should == '123.tgz'
        end
        def (@cap.dump.local).restore
          ENV['VER'].should == '123.tgz'
        end
        @cap.find_and_execute_task("dump:mirror:down")
      end
    end
  end
end
