# frozen_string_literal: true

require 'spec_helper'
require 'dump/env/filter'

describe Dump::Env::Filter do
  it 'passes everything if initialized with nil' do
    filter = described_class.new(nil)
    expect(filter.pass?('a')).to be_truthy
    expect(filter.pass?('b')).to be_truthy
    expect(filter.pass?('c')).to be_truthy
    expect(filter.pass?('d')).to be_truthy
  end

  it 'passes only specified values' do
    filter = described_class.new('a,c')
    expect(filter.pass?('a')).to be_truthy
    expect(filter.pass?('b')).to be_falsey
    expect(filter.pass?('c')).to be_truthy
    expect(filter.pass?('d')).to be_falsey
  end

  it 'does not pass anything if initialized empty' do
    filter = described_class.new('')
    expect(filter.pass?('a')).to be_falsey
    expect(filter.pass?('b')).to be_falsey
    expect(filter.pass?('c')).to be_falsey
    expect(filter.pass?('d')).to be_falsey
  end

  describe 'when initialized with -' do
    it 'passes everything except specified values' do
      filter = described_class.new('-a,c')
      expect(filter.pass?('a')).to be_falsey
      expect(filter.pass?('b')).to be_truthy
      expect(filter.pass?('c')).to be_falsey
      expect(filter.pass?('d')).to be_truthy
    end

    it 'passes everything if initialized empty' do
      filter = described_class.new('-')
      expect(filter.pass?('a')).to be_truthy
      expect(filter.pass?('b')).to be_truthy
      expect(filter.pass?('c')).to be_truthy
      expect(filter.pass?('d')).to be_truthy
    end
  end

  describe 'custom_pass?' do
    it 'passes only when any call to block returns true' do
      filter = described_class.new('a,c')
      expect(filter.custom_pass?{ |value| value == 'a' }).to be_truthy
      expect(filter.custom_pass?{ |value| value == 'b' }).to be_falsey
      expect(filter.custom_pass?{ |value| value == 'c' }).to be_truthy
      expect(filter.custom_pass?{ |value| value == 'd' }).to be_falsey
    end
  end
end
