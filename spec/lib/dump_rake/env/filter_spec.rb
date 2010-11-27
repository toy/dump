require File.dirname(__FILE__) + '/../../../spec_helper'

Filter = DumpRake::Env::Filter
describe Filter do
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

  it "should return filtered values" do
    Filter.new('a,c').filter(%w[a b c d]).should == %w[a c]
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

    it "should return filtered values" do
      Filter.new('-a,c').filter(%w[a b c d]).should == %w[b d]
    end
  end

  it "should return filtered values with additional filter" do
    Filter.new('-a,c').filter(%w[a b c d]){ |value| value == 'a' }.should == %w[a b d]
  end
end
