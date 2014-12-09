require 'spec_helper'
require 'dump_rake/env'

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

  describe 'with_env' do
    it 'should set env to new_value for duration of block' do
      ENV['LIKE'] = 'old_value'

      expect(ENV['LIKE']).to eq('old_value')
      Env.with_env('LIKE' => 'new_value') do
        expect(ENV['LIKE']).to eq('new_value')
      end
      expect(ENV['LIKE']).to eq('old_value')
    end

    it 'should use dictionary' do
      ENV['LIKE'] = 'old_value'

      expect(ENV['LIKE']).to eq('old_value')
      Env.with_env(:like => 'new_value') do
        expect(ENV['LIKE']).to eq('new_value')
      end
      expect(ENV['LIKE']).to eq('old_value')
    end
  end

  describe '[]' do
    it 'should mimic ENV' do
      ENV['VERSION'] = 'VERSION_value'
      expect(Env['VERSION']).to eq(ENV['VERSION'])
    end

    it 'should return nil on non existing env variable' do
      expect(Env['DESCRIPTON']).to eq(nil)
    end

    it 'should get first value that is set' do
      ENV['VERSION'] = 'VERSION_value'
      expect(Env[:like]).to eq('VERSION_value')
      ENV['VER'] = 'VER_value'
      expect(Env[:like]).to eq('VER_value')
      ENV['LIKE'] = 'LIKE_value'
      expect(Env[:like]).to eq('LIKE_value')
    end

    it 'should return nil for unset variable' do
      expect(Env[:desc]).to eq(nil)
    end
  end

  describe 'filter' do
    before do
      Env.instance_variable_set(:@filters, nil)
    end

    it 'should return Filter' do
      ENV['TABLES'] = 'a,b,c'
      filter = Env.filter('TABLES')
      expect(filter).to be_instance_of(Env::Filter)
      expect(filter.invert).to be_falsey
      expect(filter.values).to eq(%w[a b c])
    end

    it 'should cache created filter' do
      ENV['TABLES'] = 'a,b,c'
      ENV['TABLES2'] = 'a,b,c'
      expect(Env::Filter).to receive(:new).with('a,b,c', nil).once
      Env.filter('TABLES')
      Env.filter('TABLES')
      Env.filter('TABLES2')
    end
  end

  describe 'for_command' do
    describe 'when no vars present' do
      it 'should return empty hash for every command' do
        expect(Env.for_command(:create)).to eq({})
        expect(Env.for_command(:restore)).to eq({})
        expect(Env.for_command(:versions)).to eq({})
        expect(Env.for_command(:bad)).to eq({})
      end

      it 'should return empty hash for every command when asking for string keys' do
        expect(Env.for_command(:create, true)).to eq({})
        expect(Env.for_command(:restore, true)).to eq({})
        expect(Env.for_command(:versions, true)).to eq({})
        expect(Env.for_command(:bad, true)).to eq({})
      end
    end

    describe 'when vars are present' do
      before do
        ENV['LIKE'] = 'Version'
        ENV['DESC'] = 'Description'
      end

      it 'should return hash with symbol keys for every command' do
        expect(Env.for_command(:create)).to eq({:desc => 'Description'})
        expect(Env.for_command(:restore)).to eq({:like => 'Version'})
        expect(Env.for_command(:versions)).to eq({:like => 'Version'})
        expect(Env.for_command(:bad)).to eq({})
      end

      it 'should return hash with symbol keys for every command when asking for string keys' do
        expect(Env.for_command(:create, true)).to eq({'DESC' => 'Description'})
        expect(Env.for_command(:restore, true)).to eq({'LIKE' => 'Version'})
        expect(Env.for_command(:versions, true)).to eq({'LIKE' => 'Version'})
        expect(Env.for_command(:bad, true)).to eq({})
      end
    end
  end

  describe 'stringify!' do
    it 'should convert keys to strings' do
      @env = {:desc => 'text', :tags => 'a b c', 'LEAVE' => 'none', 'OTHER' => 'data'}
      Env.stringify!(@env)
      expect(@env).to eq({'DESC' => 'text', 'TAGS' => 'a b c', 'LEAVE' => 'none', 'OTHER' => 'data'})
    end
  end
end
