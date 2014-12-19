require 'spec_helper'
require 'dump/env'

describe Dump::Env do
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
    it 'sets env to new_value for duration of block' do
      ENV['LIKE'] = 'old_value'

      expect(ENV['LIKE']).to eq('old_value')
      described_class.with_env('LIKE' => 'new_value') do
        expect(ENV['LIKE']).to eq('new_value')
      end
      expect(ENV['LIKE']).to eq('old_value')
    end

    it 'uses dictionary' do
      ENV['LIKE'] = 'old_value'

      expect(ENV['LIKE']).to eq('old_value')
      described_class.with_env(:like => 'new_value') do
        expect(ENV['LIKE']).to eq('new_value')
      end
      expect(ENV['LIKE']).to eq('old_value')
    end
  end

  describe '[]' do
    it 'mimics ENV' do
      ENV['VERSION'] = 'VERSION_value'
      expect(described_class['VERSION']).to eq(ENV['VERSION'])
    end

    it 'returns nil on non existing env variable' do
      expect(described_class['DESCRIPTON']).to eq(nil)
    end

    it 'gets first value that is set' do
      ENV['VERSION'] = 'VERSION_value'
      expect(described_class[:like]).to eq('VERSION_value')
      ENV['VER'] = 'VER_value'
      expect(described_class[:like]).to eq('VER_value')
      ENV['LIKE'] = 'LIKE_value'
      expect(described_class[:like]).to eq('LIKE_value')
    end

    it 'returns nil for unset variable' do
      expect(described_class[:desc]).to eq(nil)
    end
  end

  describe 'filter' do
    before do
      described_class.instance_variable_set(:@filters, nil)
    end

    it 'returns Filter' do
      ENV['TABLES'] = 'a,b,c'
      filter = described_class.filter('TABLES')
      expect(filter).to be_instance_of(described_class::Filter)
      expect(filter.invert).to be_falsey
      expect(filter.values).to eq(%w[a b c])
    end

    it 'caches created filter' do
      ENV['TABLES'] = 'a,b,c'
      ENV['TABLES2'] = 'a,b,c'
      expect(described_class::Filter).to receive(:new).with('a,b,c', nil).once
      described_class.filter('TABLES')
      described_class.filter('TABLES')
      described_class.filter('TABLES2')
    end
  end

  describe 'for_command' do
    describe 'when no vars present' do
      it 'returns empty hash for every command' do
        expect(described_class.for_command(:create)).to eq({})
        expect(described_class.for_command(:restore)).to eq({})
        expect(described_class.for_command(:versions)).to eq({})
        expect(described_class.for_command(:bad)).to eq({})
      end

      it 'returns empty hash for every command when asking for string keys' do
        expect(described_class.for_command(:create, true)).to eq({})
        expect(described_class.for_command(:restore, true)).to eq({})
        expect(described_class.for_command(:versions, true)).to eq({})
        expect(described_class.for_command(:bad, true)).to eq({})
      end
    end

    describe 'when vars are present' do
      before do
        ENV['LIKE'] = 'Version'
        ENV['DESC'] = 'Description'
      end

      it 'returns hash with symbol keys for every command' do
        expect(described_class.for_command(:create)).to eq({:desc => 'Description'})
        expect(described_class.for_command(:restore)).to eq({:like => 'Version'})
        expect(described_class.for_command(:versions)).to eq({:like => 'Version'})
        expect(described_class.for_command(:bad)).to eq({})
      end

      it 'returns hash with symbol keys for every command when asking for string keys' do
        expect(described_class.for_command(:create, true)).to eq({'DESC' => 'Description'})
        expect(described_class.for_command(:restore, true)).to eq({'LIKE' => 'Version'})
        expect(described_class.for_command(:versions, true)).to eq({'LIKE' => 'Version'})
        expect(described_class.for_command(:bad, true)).to eq({})
      end
    end
  end

  describe 'stringify!' do
    it 'converts keys to strings' do
      @env = {:desc => 'text', :tags => 'a b c', 'LEAVE' => 'none', 'OTHER' => 'data'}
      described_class.stringify!(@env)
      expect(@env).to eq({'DESC' => 'text', 'TAGS' => 'a b c', 'LEAVE' => 'none', 'OTHER' => 'data'})
    end
  end
end
