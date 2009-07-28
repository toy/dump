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

  describe "for_command" do
    describe "when no vars present" do
      it "should return empty hash for every command" do
        Env.for_command(:create).should == {}
        Env.for_command(:restore).should == {}
        Env.for_command(:versions).should == {}
        Env.for_command(:bad).should == {}
      end

      it "should return empty hash for every command when asking for string keys" do
        Env.for_command(:create, true).should == {}
        Env.for_command(:restore, true).should == {}
        Env.for_command(:versions, true).should == {}
        Env.for_command(:bad, true).should == {}
      end
    end

    describe "when vars are present" do
      before do
        ENV['LIKE'] = 'Version'
        ENV['DESC'] = 'Description'
      end

      it "should return hash with symbol keys for every command" do
        Env.for_command(:create).should == {:desc => 'Description'}
        Env.for_command(:restore).should == {:like => 'Version'}
        Env.for_command(:versions).should == {:like => 'Version'}
        Env.for_command(:bad).should == {}
      end

      it "should return hash with symbol keys for every command when asking for string keys" do
        Env.for_command(:create, true).should == {'DESC' => 'Description'}
        Env.for_command(:restore, true).should == {'LIKE' => 'Version'}
        Env.for_command(:versions, true).should == {'LIKE' => 'Version'}
        Env.for_command(:bad, true).should == {}
      end
    end
  end
end
