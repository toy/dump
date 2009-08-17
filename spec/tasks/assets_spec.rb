require File.dirname(__FILE__) + '/../spec_helper'
require "rake"

describe "rake assets" do
  before do
    @rake = Rake::Application.new
    Rake.application = @rake
    load File.dirname(__FILE__) + '/../../tasks/assets.rake'
    ENV['ASSETS'] = nil
  end

  it "should set ENV['ASSETS'] to paths from config/assets" do
    data = <<-end_src
      public/images/a
      public/images/b
    end_src
    File.should_receive(:readlines).with(File.join(RAILS_ROOT, 'config', 'assets')).and_return(StringIO.new(data).readlines)
    @rake["assets"].invoke
    ENV['ASSETS'].should == 'public/images/a:public/images/b'
  end

  it "should ignore comments in config/assets" do
    data = <<-end_src
      #comment
      #comment
      public/images/a
      public/images/b
    end_src
    File.stub!(:readlines).and_return(StringIO.new(data).readlines)
    @rake["assets"].invoke
    ENV['ASSETS'].should == 'public/images/a:public/images/b'
  end

  it "should not change ENV['ASSETS'] if it already exists" do
    data = <<-end_src
      public/images/a
      public/images/b
    end_src
    File.stub!(:readlines).and_return(StringIO.new(data).readlines)
    DumpRake::Env.with_env :assets => 'public/images' do
      @rake["assets"].invoke
      ENV['ASSETS'].should == 'public/images'
    end
  end

  describe "delete" do
    before do
      FileUtils.stub!(:remove_entry_secure)
    end

    it "should require assets task" do
      @rake["assets:delete"].prerequisites.should include("assets")
    end

    describe "deleting existing assets" do
      it "should go through each asset from config" do
        ENV.stub!(:[]).with('ASSETS').and_return('images:videos')

        File.should_receive(:expand_path).with('images', RAILS_ROOT).and_return('')
        File.should_receive(:expand_path).with('videos', RAILS_ROOT).and_return('')

        @rake["assets:delete"].invoke
      end

      it "should glob all assets and delete content" do
        @assets = %w(images videos)
        ENV.stub!(:[]).with('ASSETS').and_return(@assets.join(':'))
        @assets.each do |asset|
          mask = File.join(RAILS_ROOT, asset, '*')
          paths = %w(file1 file2 dir).map{ |file| File.join(RAILS_ROOT, asset, file) }
          Dir.should_receive(:[]).with(mask).and_return([paths[0], paths[1], paths[2]])
          paths.each do |path|
            FileUtils.should_receive(:remove_entry_secure).with(path)
          end
        end

        @rake["assets:delete"].invoke
      end

      it "should not glob risky paths" do
        @assets = %w(images / /private ../ ../.. ./../ dir/.. dir/../..)
        ENV.stub!(:[]).with('ASSETS').and_return(@assets.join(':'))

        Dir.should_receive(:[]).with(File.join(RAILS_ROOT, 'images', '*')).and_return([])
        FileUtils.should_not_receive(:remove_entry_secure)

        @rake["assets:delete"].invoke
      end
    end
  end
end
