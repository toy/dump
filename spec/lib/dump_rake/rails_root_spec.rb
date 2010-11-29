require File.dirname(__FILE__) + '/../../spec_helper'

describe 'RailsRoot' do
  before do
    @root = mock('root')
    @root.should_receive(:to_s).and_return(@root)

    Object.send(:remove_const, 'Rails') if defined?(Rails)
    Object.send(:remove_const, 'RAILS_ROOT') if defined?(RAILS_ROOT)
    DumpRake.send(:remove_const, 'RailsRoot') if defined?(DumpRake::RailsRoot)
  end

  it "should use Rails if it is present" do
    Object.const_set('Rails', mock('rails'))
    Rails.should_receive(:root).and_return(@root)
    load 'dump_rake/rails_root.rb'
    DumpRake::RailsRoot.should === @root
  end

  it "should use RAILS_ROOT if it is present" do
    Object.const_set('RAILS_ROOT', @root)
    load 'dump_rake/rails_root.rb'
    DumpRake::RailsRoot.should === @root
  end

  it "should use Dir.pwd else" do
    Dir.should_receive(:pwd).and_return(@root)
    load 'dump_rake/rails_root.rb'
    DumpRake::RailsRoot.should === @root
  end
end
