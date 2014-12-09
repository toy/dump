require 'spec_helper'
require 'dump_rake/rails_root'

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
  include DumpRake::RailsRoot

  before do
    @root = double('root')
    allow(@root).to receive(:to_s).and_return(@root)
  end

  temp_remove_const Object, :Rails
  temp_remove_const Object, :RAILS_ROOT

  it 'should use Rails if it is present' do
    Object.const_set('Rails', double('rails'))
    expect(Rails).to receive(:root).and_return(@root)
    expect(rails_root).to equal(@root)
  end

  it 'should use RAILS_ROOT if it is present' do
    Object.const_set('RAILS_ROOT', @root)
    expect(rails_root).to equal(@root)
  end

  it 'should fail otherwaise' do
    expect{ rails_root }.to raise_error
  end
end
