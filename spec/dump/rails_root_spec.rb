require 'spec_helper'
require 'dump/rails_root'

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

describe Dump::RailsRoot do
  include described_class

  before do
    @root = double('root')
    allow(@root).to receive(:to_s).and_return(@root)
  end

  temp_remove_const Object, :Rails
  temp_remove_const Object, :RAILS_ROOT

  it 'uses Rails if it is present' do
    Object.const_set('Rails', double('rails'))
    expect(Rails).to receive(:root).and_return(@root)
    expect(rails_root).to equal(@root)
  end

  it 'uses RAILS_ROOT if it is present' do
    Object.const_set('RAILS_ROOT', @root)
    expect(rails_root).to equal(@root)
  end

  it 'fails otherwaise' do
    expect{ rails_root }.to raise_error 'Unknown rails app root'
  end
end
