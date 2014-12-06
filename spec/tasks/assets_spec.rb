require File.dirname(__FILE__) + '/../spec_helper'
require 'rake'

describe 'rake assets' do
  before do
    @rake = Rake::Application.new
    Rake.application = @rake
    load File.dirname(__FILE__) + '/../../lib/tasks/assets.rake'
    ENV['ASSETS'] = nil
  end

  it "should set ENV['ASSETS'] to paths from config/assets" do
    data = <<-end_src
      public/images/a
      public/images/b
    end_src
    expect(File).to receive(:readlines).with(File.join(DumpRake::RailsRoot, 'config/assets')).and_return(StringIO.new(data).readlines)
    @rake['assets'].invoke
    expect(ENV['ASSETS']).to eq('public/images/a:public/images/b')
  end

  it 'should ignore comments in config/assets' do
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

  it "should not change ENV['ASSETS'] if it already exists" do
    data = <<-end_src
      public/images/a
      public/images/b
    end_src
    allow(File).to receive(:readlines).and_return(StringIO.new(data).readlines)
    DumpRake::Env.with_env :assets => 'public/images' do
      @rake['assets'].invoke
      expect(ENV['ASSETS']).to eq('public/images')
    end
  end

  describe 'delete' do
    before do
      allow(FileUtils).to receive(:remove_entry)
    end

    it 'should require assets task' do
      expect(@rake['assets:delete'].prerequisites).to include('assets')
    end

    describe 'deleting existing assets' do
      it 'should go through each asset from config' do
        allow(ENV).to receive(:[]).with('ASSETS').and_return('images:videos')

        expect(File).to receive(:expand_path).with('images', DumpRake::RailsRoot).and_return('')
        expect(File).to receive(:expand_path).with('videos', DumpRake::RailsRoot).and_return('')

        @rake['assets:delete'].invoke
      end

      it 'should glob all assets and delete content' do
        @assets = %w[images videos]
        allow(ENV).to receive(:[]).with('ASSETS').and_return(@assets.join(':'))
        @assets.each do |asset|
          mask = File.join(DumpRake::RailsRoot, asset, '*')
          paths = %w[file1 file2 dir].map{ |file| File.join(DumpRake::RailsRoot, asset, file) }
          expect(Dir).to receive(:[]).with(mask).and_return([paths[0], paths[1], paths[2]])
          paths.each do |path|
            expect(FileUtils).to receive(:remove_entry).with(path)
          end
        end

        @rake['assets:delete'].invoke
      end

      it 'should not glob risky paths' do
        @assets = %w[images / /private ../ ../.. ./../ dir/.. dir/../..]
        allow(ENV).to receive(:[]).with('ASSETS').and_return(@assets.join(':'))

        expect(Dir).to receive(:[]).with(File.join(DumpRake::RailsRoot, 'images/*')).and_return([])
        expect(Dir).to receive(:[]).with(File.join(DumpRake::RailsRoot, '*')).and_return([])
        expect(FileUtils).not_to receive(:remove_entry)

        @rake['assets:delete'].invoke
      end
    end
  end
end
