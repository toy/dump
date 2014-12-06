require File.dirname(__FILE__) + '/../spec_helper'
require 'rake'

describe 'rake dump' do
  before do
    @rake = Rake::Application.new
    Rake.application = @rake
    load File.dirname(__FILE__) + '/../../lib/tasks/dump.rake'
    Rake::Task.define_task(:environment)
  end

  %w[versions create restore cleanup].each do |task|
    describe task do
      it 'should require environment task' do
        expect(@rake["dump:#{task}"].prerequisites).to include('environment')
      end
    end
  end

  describe 'versions' do
    before do
      @task = @rake['dump:versions']
    end

    it 'should call DumpRake.versions' do
      expect(DumpRake).to receive(:versions)
      @task.invoke
    end

    DumpRake::Env.variable_names_for_command(:versions) do |variable|
      DumpRake::Env::DICTIONARY[variable].each do |name|
        it "should pass version if it is set through environment variable #{name}" do
          expect(DumpRake).to receive(:versions).with(variable => '21376')
          DumpRake::Env.with_env name => '21376' do
            @task.invoke
          end
        end
      end
    end
  end

  describe 'create' do
    before do
      @task = @rake['dump:create']
    end

    it 'should call DumpRake.create' do
      expect(DumpRake).to receive(:create)
      @task.invoke
    end

    DumpRake::Env.variable_names_for_command(:create) do |variable|
      DumpRake::Env::DICTIONARY[variable].each do |name|
        it "should pass description if it is set through environment variable #{name}" do
          expect(DumpRake).to receive(:create).with(variable => 'simple dump')
          DumpRake::Env.with_env name => 'simple dump' do
            @task.invoke
          end
        end
      end
    end
  end

  describe 'restore' do
    before do
      @task = @rake['dump:restore']
    end

    it 'should call DumpRake.restore' do
      expect(DumpRake).to receive(:restore)
      @task.invoke
    end

    DumpRake::Env.variable_names_for_command(:restore) do |variable|
      DumpRake::Env::DICTIONARY[variable].each do |name|
        it "should pass version if it is set through environment variable #{name}" do
          expect(DumpRake).to receive(:restore).with(variable => '21378')
          DumpRake::Env.with_env name => '21378' do
            @task.invoke
          end
        end
      end
    end
  end

  describe 'cleanup' do
    before do
      @task = @rake['dump:cleanup']
    end

    it 'should call DumpRake.cleanup' do
      expect(DumpRake).to receive(:cleanup)
      @task.invoke
    end

    DumpRake::Env.variable_names_for_command(:cleanup) do |variable|
      DumpRake::Env::DICTIONARY[variable].each do |name|
        it "should pass number of dumps to leave if it is set through environment variable #{name}" do
          expect(DumpRake).to receive(:versions).with(variable => '21376')
          DumpRake::Env.with_env name => '21376' do
            @task.invoke
          end
        end
      end
    end
  end
end
