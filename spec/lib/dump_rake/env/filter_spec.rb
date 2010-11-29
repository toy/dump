require File.dirname(__FILE__) + '/../../../spec_helper'

Filter = DumpRake::Env::Filter
describe Filter do
  it "should pass everything if initialized with nil" do
    filter = Filter.new(nil)
    filter.pass?('a').should be_true
    filter.pass?('b').should be_true
    filter.pass?('c').should be_true
    filter.pass?('d').should be_true
  end

  it "should pass only specified values" do
    filter = Filter.new('a,c')
    filter.pass?('a').should be_true
    filter.pass?('b').should be_false
    filter.pass?('c').should be_true
    filter.pass?('d').should be_false
  end

  it "should not pass anything if initialized empty" do
    filter = Filter.new('')
    filter.pass?('a').should be_false
    filter.pass?('b').should be_false
    filter.pass?('c').should be_false
    filter.pass?('d').should be_false
  end

  describe "when initialized with -" do
    it "should pass everything except specified values" do
      filter = Filter.new('-a,c')
      filter.pass?('a').should be_false
      filter.pass?('b').should be_true
      filter.pass?('c').should be_false
      filter.pass?('d').should be_true
    end

    it "should pass everything if initialized empty" do
      filter = Filter.new('-')
      filter.pass?('a').should be_true
      filter.pass?('b').should be_true
      filter.pass?('c').should be_true
      filter.pass?('d').should be_true
    end
  end

  describe "custom_pass?" do
    it "should pass only when any call to block returns true" do
      filter = Filter.new('a,c')
      filter.custom_pass?{ |value| value == 'a' }.should be_true
      filter.custom_pass?{ |value| value == 'b' }.should be_false
      filter.custom_pass?{ |value| value == 'c' }.should be_true
      filter.custom_pass?{ |value| value == 'd' }.should be_false
    end
  end
end
