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
    expect(@root).to receive(:to_s).and_return(@root)
  end

  temp_remove_const Object, :Rails
  temp_remove_const Object, :RAILS_ROOT
  temp_remove_const DumpRake, :RailsRoot

  it "should use Rails if it is present" do
    Object.const_set('Rails', double('rails'))
    expect(Rails).to receive(:root).and_return(@root)
    load 'dump_rake/rails_root.rb'
    expect(DumpRake::RailsRoot).to be === @root
  end

  it "should use RAILS_ROOT if it is present" do
    Object.const_set('RAILS_ROOT', @root)
    load 'dump_rake/rails_root.rb'
    expect(DumpRake::RailsRoot).to be === @root
  end

  it "should use Dir.pwd else" do
    expect(Dir).to receive(:pwd).and_return(@root)
    load 'dump_rake/rails_root.rb'
    expect(DumpRake::RailsRoot).to be === @root
  end
end
