require File.dirname(__FILE__) + '/../../spec_helper'

Env = DumpRake::Env
describe Env do
  def silence_warnings
    old_verbose, $VERBOSE = $VERBOSE, nil
    yield
  ensure
    $VERBOSE = old_verbose
  end

  before do
    silence_warnings do
      @old_env, ENV = ENV, {}
    end
  end

  after do
    silence_warnings do
      ENV = @old_env
    end
  end

  describe "with_env" do
    it "should set env to new_value for duration of block" do
      ENV['LIKE'] = 'old_value'

      ENV['LIKE'].should == 'old_value'
      Env.with_env('LIKE' => 'new_value') do
        ENV['LIKE'].should == 'new_value'
      end
      ENV['LIKE'].should == 'old_value'
    end

    it "should use dictionary" do
      ENV['LIKE'] = 'old_value'

      ENV['LIKE'].should == 'old_value'
      Env.with_env(:like => 'new_value') do
        ENV['LIKE'].should == 'new_value'
      end
      ENV['LIKE'].should == 'old_value'
    end
  end

  describe "[]" do
    it "should mimic ENV" do
      ENV['VERSION'] = 'VERSION_value'
      Env['VERSION'].should == ENV['VERSION']
    end

    it "should return nil on non existing env variable" do
      Env['DESCRIPTON'].should == nil
    end

    it "should get first value that is set" do
      ENV['VERSION'] = 'VERSION_value'
      Env[:like].should == 'VERSION_value'
      ENV['VER'] = 'VER_value'
      Env[:like].should == 'VER_value'
      ENV['LIKE'] = 'LIKE_value'
      Env[:like].should == 'LIKE_value'
    end

    it "should return nil for unset variable" do
      Env[:desc].should == nil
    end
  end
end
