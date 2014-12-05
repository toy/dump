require File.dirname(__FILE__) + '/../../../spec_helper'

Filter = DumpRake::Env::Filter
describe Filter do
  it "should pass everything if initialized with nil" do
    filter = Filter.new(nil)
    expect(filter.pass?('a')).to be_truthy
    expect(filter.pass?('b')).to be_truthy
    expect(filter.pass?('c')).to be_truthy
    expect(filter.pass?('d')).to be_truthy
  end

  it "should pass only specified values" do
    filter = Filter.new('a,c')
    expect(filter.pass?('a')).to be_truthy
    expect(filter.pass?('b')).to be_falsey
    expect(filter.pass?('c')).to be_truthy
    expect(filter.pass?('d')).to be_falsey
  end

  it "should not pass anything if initialized empty" do
    filter = Filter.new('')
    expect(filter.pass?('a')).to be_falsey
    expect(filter.pass?('b')).to be_falsey
    expect(filter.pass?('c')).to be_falsey
    expect(filter.pass?('d')).to be_falsey
  end

  describe "when initialized with -" do
    it "should pass everything except specified values" do
      filter = Filter.new('-a,c')
      expect(filter.pass?('a')).to be_falsey
      expect(filter.pass?('b')).to be_truthy
      expect(filter.pass?('c')).to be_falsey
      expect(filter.pass?('d')).to be_truthy
    end

    it "should pass everything if initialized empty" do
      filter = Filter.new('-')
      expect(filter.pass?('a')).to be_truthy
      expect(filter.pass?('b')).to be_truthy
      expect(filter.pass?('c')).to be_truthy
      expect(filter.pass?('d')).to be_truthy
    end
  end

  describe "custom_pass?" do
    it "should pass only when any call to block returns true" do
      filter = Filter.new('a,c')
      expect(filter.custom_pass?{ |value| value == 'a' }).to be_truthy
      expect(filter.custom_pass?{ |value| value == 'b' }).to be_falsey
      expect(filter.custom_pass?{ |value| value == 'c' }).to be_truthy
      expect(filter.custom_pass?{ |value| value == 'd' }).to be_falsey
    end
  end
end
