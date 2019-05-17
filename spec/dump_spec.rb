# frozen_string_literal: true

require 'spec_helper'
require 'dump'

describe Dump do
  describe 'versions' do
    it 'calls Snapshot.list if called without version' do
      expect(Dump::Snapshot).to receive(:list).and_return([])
      described_class.versions
    end

    it 'calls Snapshot.list with options if called with version' do
      expect(Dump::Snapshot).to receive(:list).with(:like => '123').and_return([])
      described_class.versions(:like => '123')
    end

    it 'prints versions' do
      expect(Dump::Snapshot).to receive(:list).and_return(%w[123.tgz 456.tgz])
      expect(grab_output do
        described_class.versions
      end[:stdout]).to eq("123.tgz\n456.tgz\n")
    end

    it 'does not show summary if not asked for' do
      dumps = %w[123.tgz 456.tgz].map do |s|
        dump = double("dump_#{s}", :path => double("dump_#{s}_path"))
        expect(Dump::Reader).not_to receive(:summary)
        dump
      end

      expect(Dump::Snapshot).to receive(:list).and_return(dumps)
      grab_output do
        expect($stderr).not_to receive(:puts)
        described_class.versions
      end
    end

    it 'shows summary if asked for' do
      dumps = %w[123.tgz 456.tgz].map do |s|
        dump = double("dump_#{s}", :path => double("dump_#{s}_path"))
        expect(Dump::Reader).to receive(:summary).with(dump.path)
        dump
      end

      expect(Dump::Snapshot).to receive(:list).and_return(dumps)
      grab_output do
        expect($stderr).not_to receive(:puts)
        described_class.versions(:summary => '1')
      end
    end

    it 'shows summary with scmema if asked for' do
      dumps = %w[123.tgz 456.tgz].map do |s|
        dump = double("dump_#{s}", :path => double("dump_#{s}_path"))
        expect(Dump::Reader).to receive(:summary).with(dump.path, :schema => true)
        dump
      end

      expect(Dump::Snapshot).to receive(:list).and_return(dumps)
      grab_output do
        expect($stderr).not_to receive(:puts)
        described_class.versions(:summary => '2')
      end
    end

    it 'shows output to stderr if summary raises error' do
      allow(Dump::Reader).to receive(:summary)
      dumps = %w[123.tgz 456.tgz].map do |s|
        double("dump_#{s}", :path => double("dump_#{s}_path"))
      end
      expect(Dump::Reader).to receive(:summary).with(dumps[1].path).and_raise('terrible error')

      expect(Dump::Snapshot).to receive(:list).and_return(dumps)
      grab_output do
        allow($stderr).to receive(:puts)
        expect($stderr).to receive(:puts) do |s|
          expect(s['terrible error']).not_to be_nil
        end
        described_class.versions(:summary => 'true')
      end
    end
  end

  describe 'create' do
    describe 'naming' do
      it "creates file in 'rails app root'/dump" do
        allow(File).to receive(:rename)
        expect(Dump::Writer).to receive(:create) do |path|
          expect(File.dirname(path)).to eq(File.join(described_class.rails_root, 'dump'))
        end
        grab_output do
          described_class.create
        end
      end

      it "creates file with name like 'yyyymmddhhmmss.tmp' when called without description" do
        allow(File).to receive(:rename)
        expect(Dump::Writer).to receive(:create) do |path|
          expect(File.basename(path)).to match(/^\d{14}\.tmp$/)
        end
        grab_output do
          described_class.create
        end
      end

      it "creates file with name like 'yyyymmddhhmmss-Some text and _.tmp' when called with description 'Some text and !@'" do
        allow(File).to receive(:rename)
        expect(Dump::Writer).to receive(:create) do |path|
          expect(File.basename(path)).to match(/^\d{14}-Some text and _\.tmp$/)
        end
        grab_output do
          described_class.create(:desc => 'Some text and !@')
        end
      end

      it "creates file with name like 'yyyymmddhhmmss@super tag,second.tmp' when called with description 'Some text and !@'" do
        allow(File).to receive(:rename)
        expect(Dump::Writer).to receive(:create) do |path|
          expect(File.basename(path)).to match(/^\d{14}-Some text and _\.tmp$/)
        end
        grab_output do
          described_class.create(:desc => 'Some text and !@')
        end
      end

      it 'renames file after creating' do
        expect(File).to receive(:rename) do |tmp_path, tgz_path|
          expect(File.basename(tmp_path)).to match(/^\d{14}-Some text and _\.tmp$/)
          expect(File.basename(tgz_path)).to match(/^\d{14}-Some text and _\.tgz$/)
        end
        allow(Dump::Writer).to receive(:create)
        grab_output do
          described_class.create(:desc => 'Some text and !@')
        end
      end

      it 'outputs file name' do
        allow(File).to receive(:rename)
        allow(Dump::Writer).to receive(:create)
        expect(grab_output do
          described_class.create(:desc => 'Some text and !@')
        end[:stdout]).to match(/^\d{14}-Some text and _\.tgz$/)
      end
    end

    describe 'writing' do
      it 'dumps schema, tables, assets' do
        allow(File).to receive(:rename)
        @dump = double('dump')
        expect(Dump::Writer).to receive(:create)

        grab_output do
          described_class.create
        end
      end
    end
  end

  describe 'restore' do
    describe 'without version' do
      it 'calls Snapshot.list' do
        allow(Dump::Snapshot).to receive(:list)
        expect(Dump::Snapshot).to receive(:list).and_return([])
        grab_output do
          described_class.restore
        end
      end

      it 'does not call Reader.restore and should call Snapshot.list and output it to $stderr if there are no versions at all' do
        allow(Dump::Snapshot).to receive(:list).and_return([])
        expect(Dump::Reader).not_to receive(:restore)
        all_dumps = double('all_dumps')
        expect(Dump::Snapshot).to receive(:list).with(no_args).and_return(all_dumps)
        grab_output do
          expect($stderr).to receive(:puts).with(kind_of(String))
          expect($stderr).to receive(:puts).with(all_dumps)
          described_class.restore
        end
      end

      it 'does not call Reader.restore and should call Snapshot.list and output it to $stderr if there are no versions at all' do
        allow(Dump::Snapshot).to receive(:list).and_return([])
        expect(Dump::Reader).not_to receive(:restore)
        all_dumps = double('all_dumps')
        expect(Dump::Snapshot).to receive(:list).with(no_args).and_return(all_dumps)
        grab_output do
          expect($stderr).to receive(:puts).with(kind_of(String))
          expect($stderr).to receive(:puts).with(all_dumps)
          described_class.restore('213')
        end
      end

      it 'calls Reader.restore if there are versions' do
        @dump = double('dump', :path => 'dump/213.tgz')
        expect(Dump::Snapshot).to receive(:list).once.and_return([@dump])
        expect(Dump::Reader).to receive(:restore).with('dump/213.tgz')
        grab_output do
          expect($stderr).not_to receive(:puts)
          described_class.restore
        end
      end
    end

    describe 'with version' do
      it 'calls Snapshot.list with options' do
        allow(Dump::Snapshot).to receive(:list)
        expect(Dump::Snapshot).to receive(:list).with(:like => '213').and_return([])
        grab_output do
          described_class.restore(:like => '213')
        end
      end

      it 'does not call Reader.restore and should call versions if desired version not found' do
        allow(Dump::Snapshot).to receive(:list).and_return([])
        expect(Dump::Reader).not_to receive(:restore)
        all_dumps = double('all_dumps')
        expect(Dump::Snapshot).to receive(:list).with(no_args).and_return(all_dumps)
        grab_output do
          expect($stderr).to receive(:puts).with(kind_of(String))
          expect($stderr).to receive(:puts).with(all_dumps)
          described_class.restore('213')
        end
      end

      it 'calls Reader.restore if there is desired version' do
        @dump = double('dump', :path => 'dump/213.tgz')
        expect(Dump::Snapshot).to receive(:list).once.and_return([@dump])
        expect(Dump::Reader).to receive(:restore).with('dump/213.tgz')
        expect(described_class).not_to receive(:versions)
        grab_output do
          expect($stderr).not_to receive(:puts)
          described_class.restore(:like => '213')
        end
      end

      it 'calls Reader.restore on last version if found multiple matching versions' do
        @dump_a = double('dump_a', :path => 'dump/213-a.tgz')
        @dump_b = double('dump_b', :path => 'dump/213-b.tgz')
        expect(Dump::Snapshot).to receive(:list).once.and_return([@dump_a, @dump_b])
        expect(Dump::Reader).to receive(:restore).with('dump/213-b.tgz')
        grab_output do
          expect($stderr).not_to receive(:puts)
          described_class.restore(:like => '213')
        end
      end
    end
  end

  describe 'cleanup' do
    it 'calls ask for all files in dump dir and for dumps' do
      expect(Dump::Snapshot).to receive(:list).with(:all => true).and_return([])
      expect(Dump::Snapshot).to receive(:list).with({}).and_return([])
      described_class.cleanup
    end

    it 'calls Snapshot.list with options if called with version and tags' do
      expect(Dump::Snapshot).to receive(:list).with(:like => '123', :tags => 'a,b,c', :all => true).and_return([])
      expect(Dump::Snapshot).to receive(:list).with(:like => '123', :tags => 'a,b,c').and_return([])
      described_class.cleanup(:like => '123', :tags => 'a,b,c')
    end

    {
      {} => [0..4],
      {:leave => '3'} => [0..6],
      {:leave => '5'} => [0..4],
      {:leave => '9'} => [0],
      {:leave => '10'} => [],
      {:leave => '15'} => [],
      {:leave => 'none'} => [0..9],
    }.each do |options, ids|
      it "calls delete #{ids} dumps when called with #{options}" do
        dumps = %w[a b c d e f g h i j].map do |s|
          double("dump_#{s}", :ext => 'tgz', :path => double("dump_#{s}_path"))
        end
        tmp_dumps = %w[a b c].map do |s|
          double("tmp_dump_#{s}", :ext => 'tmp', :path => double("tmp_dump_#{s}_path"))
        end
        all_dumps = tmp_dumps[0, 1] + dumps[0, 5] + tmp_dumps[1, 1] + dumps[5, 5] + tmp_dumps[2, 1]

        (dumps.values_at(*ids) + [tmp_dumps[0], tmp_dumps[2]]).each do |dump|
          expect(dump).to receive(:lock).and_yield
          expect(dump.path).to receive(:unlink)
        end
        [tmp_dumps[1]].each do |dump|
          expect(dump).to receive(:lock)
          expect(dump.path).not_to receive(:unlink)
        end
        (dumps - dumps.values_at(*ids)).each do |dump|
          expect(dump).not_to receive(:lock)
          expect(dump.path).not_to receive(:unlink)
        end

        expect(Dump::Snapshot).to receive(:list).with(hash_including(:all => true)).and_return(all_dumps)
        expect(Dump::Snapshot).to receive(:list).with(hash_not_including(:all => true)).and_return(dumps)
        grab_output do
          described_class.cleanup({:like => '123', :tags => 'a,b,c'}.merge(options))
        end
      end
    end

    it 'prints to stderr if can not delete dump' do
      dumps = %w[a b c d e f g h i j].map do |s|
        dump = double("dump_#{s}", :ext => 'tgz', :path => double("dump_#{s}_path"))
        allow(dump).to receive(:lock).and_yield
        allow(dump.path).to receive(:unlink)
        dump
      end

      expect(dumps[3].path).to receive(:unlink).and_raise('Horrible error')

      allow(Dump::Snapshot).to receive(:list).and_return(dumps)
      grab_output do
        allow($stderr).to receive(:puts)
        expect($stderr).to receive(:puts) do |s|
          expect(s[dumps[3].path.to_s]).not_to be_nil
          expect(s['Horrible error']).not_to be_nil
        end
        described_class.cleanup
      end
    end

    it "raises if called with :leave which is not a number or 'none'" do
      expect do
        described_class.cleanup(:leave => 'nothing')
      end.to raise_error ArgumentError, /number or "none"/
    end
  end
end
