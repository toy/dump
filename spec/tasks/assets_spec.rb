# frozen_string_literal: true

require 'spec_helper'
require 'dump'
require 'rake'

describe 'rake assets' do
  before do
    @rake = Rake::Application.new
    Rake.application = @rake
    load 'tasks/assets.rake'
    ENV['ASSETS'] = nil
  end

  it "sets ENV['ASSETS'] to paths from config/assets" do
    data = <<-end_src
      public/images/a
      public/images/b
    end_src
    expect(File).to receive(:readlines).with(File.join(Dump.rails_root, 'config/assets')).and_return(StringIO.new(data).readlines)
    @rake['assets'].invoke
    expect(ENV['ASSETS']).to eq('public/images/a:public/images/b')
  end

  it 'ignores comments in config/assets' do
    data = <<-end_src
      #comment
      #comment
      public/images/a
      public/images/b
    end_src
    allow(File).to receive(:readlines).and_return(StringIO.new(data).readlines)
    @rake['assets'].invoke
    expect(ENV['ASSETS']).to eq('public/images/a:public/images/b')
  end

  it "does not change ENV['ASSETS'] if it already exists" do
    data = <<-end_src
      public/images/a
      public/images/b
    end_src
    allow(File).to receive(:readlines).and_return(StringIO.new(data).readlines)
    Dump::Env.with_env :assets => 'public/images' do
      @rake['assets'].invoke
      expect(ENV['ASSETS']).to eq('public/images')
    end
  end

  describe 'delete' do
    before do
      allow(FileUtils).to receive(:remove_entry)
    end

    it 'requires assets task' do
      expect(@rake['assets:delete'].prerequisites).to include('assets')
    end

    describe 'deleting existing assets' do
      it 'goes through each asset from config' do
        allow(ENV).to receive(:[]).with('ASSETS').and_return('images:videos')

        expect(File).to receive(:expand_path).with('images', Dump.rails_root).and_return('')
        expect(File).to receive(:expand_path).with('videos', Dump.rails_root).and_return('')

        @rake['assets:delete'].invoke
      end

      it 'globs all assets and deletes content' do
        @assets = %w[images videos]
        allow(ENV).to receive(:[]).with('ASSETS').and_return(@assets.join(':'))
        @assets.each do |asset|
          mask = File.join(Dump.rails_root, asset, '*')
          paths = %w[file1 file2 dir].map{ |file| File.join(Dump.rails_root, asset, file) }
          expect(Dir).to receive(:[]).with(mask).and_return([paths[0], paths[1], paths[2]])
          paths.each do |path|
            expect(FileUtils).to receive(:remove_entry).with(path)
          end
        end

        @rake['assets:delete'].invoke
      end

      it 'does not glob risky paths' do
        @assets = %w[images / /private ../ ../.. ./../ dir/.. dir/../..]
        allow(ENV).to receive(:[]).with('ASSETS').and_return(@assets.join(':'))

        expect(Dir).to receive(:[]).with(File.join(Dump.rails_root, 'images/*')).and_return([])
        expect(Dir).to receive(:[]).with(File.join(Dump.rails_root, '*')).and_return([])
        expect(FileUtils).not_to receive(:remove_entry)

        @rake['assets:delete'].invoke
      end
    end
  end
end
