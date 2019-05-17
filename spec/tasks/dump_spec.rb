# frozen_string_literal: true

require 'spec_helper'
require 'dump'
require 'rake'

describe 'rake dump' do
  before do
    @rake = Rake::Application.new
    Rake.application = @rake
    load 'tasks/dump.rake'
    Rake::Task.define_task(:environment)
  end

  %w[versions create restore cleanup].each do |task|
    describe task do
      it 'requires environment task' do
        expect(@rake["dump:#{task}"].prerequisites).to include('environment')
      end
    end
  end

  describe 'versions' do
    before do
      @task = @rake['dump:versions']
    end

    it 'calls Dump.versions' do
      expect(Dump).to receive(:versions)
      @task.invoke
    end

    Dump::Env.variable_names_for_command(:versions) do |variable|
      Dump::Env::DICTIONARY[variable].each do |name|
        it "passes version if it is set through environment variable #{name}" do
          expect(Dump).to receive(:versions).with(variable => '21376')
          Dump::Env.with_env name => '21376' do
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

    it 'calls Dump.create' do
      expect(Dump).to receive(:create)
      @task.invoke
    end

    Dump::Env.variable_names_for_command(:create) do |variable|
      Dump::Env::DICTIONARY[variable].each do |name|
        it "passes description if it is set through environment variable #{name}" do
          expect(Dump).to receive(:create).with(variable => 'simple dump')
          Dump::Env.with_env name => 'simple dump' do
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

    it 'calls Dump.restore' do
      expect(Dump).to receive(:restore)
      @task.invoke
    end

    Dump::Env.variable_names_for_command(:restore) do |variable|
      Dump::Env::DICTIONARY[variable].each do |name|
        it "passes version if it is set through environment variable #{name}" do
          expect(Dump).to receive(:restore).with(variable => '21378')
          Dump::Env.with_env name => '21378' do
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

    it 'calls Dump.cleanup' do
      expect(Dump).to receive(:cleanup)
      @task.invoke
    end

    Dump::Env.variable_names_for_command(:cleanup) do |variable|
      Dump::Env::DICTIONARY[variable].each do |name|
        it "passes number of dumps to leave if it is set through environment variable #{name}" do
          expect(Dump).to receive(:versions).with(variable => '21376')
          Dump::Env.with_env name => '21376' do
            @task.invoke
          end
        end
      end
    end
  end
end
