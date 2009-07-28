require File.dirname(__FILE__) + '/../spec_helper'
require "rake"

describe "rake dump" do
  before do
    @rake = Rake::Application.new
    Rake.application = @rake
    load File.dirname(__FILE__) + '/../../tasks/dump.rake'
    Rake::Task.define_task(:environment)
  end

  %w(versions create restore).each do |task|
    describe task do
      it "should require environment task" do
        @rake["dump:#{task}"].prerequisites.should include("environment")
      end
    end
  end

  describe "versions" do
    before do
      @task = @rake["dump:versions"]
    end

    it "should call DumpRake.versions" do
      DumpRake.should_receive(:versions)
      @task.invoke
    end

    DumpRake::Env::DICTIONARY[:like].each do |name|
      it "should pass version if it is set through environment variable #{name}" do
        DumpRake.should_receive(:versions).with(:like => '21376')
        DumpRake::Env.with_env name => '21376' do
          @task.invoke
        end
      end
    end
  end

  describe "create" do
    before do
      @task = @rake["dump:create"]
    end

    it "should call DumpRake.create" do
      DumpRake.should_receive(:create)
      @task.invoke
    end

    DumpRake::Env::DICTIONARY[:desc].each do |name|
      it "should pass description if it is set through environment variable #{name}" do
        DumpRake.should_receive(:create).with(:description => 'simple dump')
        DumpRake::Env.with_env name => 'simple dump' do
          @task.invoke
        end
      end
    end
  end

  describe "restore" do
    before do
      @task = @rake["dump:restore"]
    end

    it "should call DumpRake.restore" do
      DumpRake.should_receive(:restore)
      @task.invoke
    end

    DumpRake::Env::DICTIONARY[:like].each do |name|
      it "should pass version if it is set through environment variable #{name}" do
        DumpRake.should_receive(:restore).with(:like => '21378')
        DumpRake::Env.with_env name => '21378' do
          @task.invoke
        end
      end
    end
  end
end
