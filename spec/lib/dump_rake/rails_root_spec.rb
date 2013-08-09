require File.dirname(__FILE__) + '/../../spec_helper'

def temp_remove_const(where, which)
  around do |example|
    if where.const_defined?(which)
      old = where.send(:const_get, which)
      where.send(:remove_const, which)
      example.run
      where.send(:remove_const, which) if where.const_defined?(which)
      where.const_set(which, old)
    else
      example.run
    end
  end
end

describe 'RailsRoot' do
  before do
    @root = double('root')
    @root.should_receive(:to_s).and_return(@root)
  end

  temp_remove_const Object, :Rails
  temp_remove_const Object, :RAILS_ROOT
  temp_remove_const DumpRake, :RailsRoot

  it "should use Rails if it is present" do
    Object.const_set('Rails', double('rails'))
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
