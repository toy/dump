require 'spec_helper'

describe DumpRake::Snapshot do
  def dump_path(file_name)
    File.join(DumpRake::RailsRoot, 'dump', file_name)
  end

  def new_dump(file_name)
    DumpRake::Snapshot.new(dump_path(file_name))
  end

  describe 'lock' do
    before do
      @yield_receiver = double('yield_receiver')
    end

    it 'should not yield if file does not exist' do
      expect(@yield_receiver).not_to receive(:fire)

      DumpRake::Snapshot.new('hello').lock do
        @yield_receiver.fire
      end
    end

    it 'should not yield if file can not be locked' do
      expect(@yield_receiver).not_to receive(:fire)

      @file = double('file')
      expect(@file).to receive(:flock).with(File::LOCK_EX | File::LOCK_NB).and_return(nil)
      expect(@file).to receive(:flock).with(File::LOCK_UN)
      expect(@file).to receive(:close)
      expect(File).to receive(:open).and_return(@file)

      DumpRake::Snapshot.new('hello').lock do
        @yield_receiver.fire
      end
    end

    it 'should yield if file can not be locked' do
      expect(@yield_receiver).to receive(:fire)

      @file = double('file')
      expect(@file).to receive(:flock).with(File::LOCK_EX | File::LOCK_NB).and_return(true)
      expect(@file).to receive(:flock).with(File::LOCK_UN)
      expect(@file).to receive(:close)
      expect(File).to receive(:open).and_return(@file)

      DumpRake::Snapshot.new('hello').lock do
        @yield_receiver.fire
      end
    end
  end

  describe 'new' do
    it 'should init with path if String sent' do
      expect(DumpRake::Snapshot.new('hello').path).to eq(Pathname('hello'))
    end

    it 'should init with path if Pathname sent' do
      expect(DumpRake::Snapshot.new(Pathname('hello')).path).to eq(Pathname('hello'))
    end

    describe 'with options' do
      before do
        @time = double('time')
        allow(@time).to receive(:utc).and_return(@time)
        allow(@time).to receive(:strftime).and_return('19650414065945')
        allow(Time).to receive(:now).and_return(@time)
      end

      it 'should generate path with no options' do
        expect(DumpRake::Snapshot.new.path).to eq(Pathname('19650414065945.tgz'))
      end

      it 'should generate with dir' do
        expect(DumpRake::Snapshot.new(:dir => 'dump_dir').path).to eq(Pathname('dump_dir/19650414065945.tgz'))
      end

      it 'should generate path with description' do
        expect(DumpRake::Snapshot.new(:dir => 'dump_dir', :desc => 'hello world').path).to eq(Pathname('dump_dir/19650414065945-hello world.tgz'))
      end

      it 'should generate path with tags' do
        expect(DumpRake::Snapshot.new(:dir => 'dump_dir', :tags => ' mirror, hello world ').path).to eq(Pathname('dump_dir/19650414065945@hello world,mirror.tgz'))
      end

      it 'should generate path with description and tags' do
        expect(DumpRake::Snapshot.new(:dir => 'dump_dir', :desc => 'Anniversary backup', :tags => ' mirror, hello world ').path).to eq(Pathname('dump_dir/19650414065945-Anniversary backup@hello world,mirror.tgz'))
      end
    end
  end

  describe 'versions' do
    describe 'list' do
      def stub_glob
        paths = %w[123 345 567].map do |name|
          path = dump_path("#{name}.tgz")
          expect(File).to receive(:file?).with(path).at_least(1).and_return(true)
          path
        end
        allow(Dir).to receive(:[]).and_return(paths)
      end

      it 'should search for files in dump dir when asked for list' do
        expect(Dir).to receive(:[]).with(dump_path('*.tgz')).and_return([])
        DumpRake::Snapshot.list
      end

      it 'should return selves instances for each found file' do
        stub_glob
        DumpRake::Snapshot.list.all?{ |dump| expect(dump).to be_a(DumpRake::Snapshot) }
      end

      it 'should return dumps with name containting :like' do
        stub_glob
        expect(DumpRake::Snapshot.list(:like => '3')).to eq(DumpRake::Snapshot.list.values_at(0, 1))
      end
    end

    describe 'with tags' do
      before do
        #             0        1  2    3      4      5        6    7    8      9  10   11   12     13 14 15   16
        dumps_tags = [''] + %w[a  a,d  a,d,o  a,d,s  a,d,s,o  a,o  a,s  a,s,o  d  d,o  d,s  d,s,o  o  s  s,o  z]
        paths = dumps_tags.each_with_index.map do |dump_tags, i|
          path = dump_path("196504140659#{10 + i}@#{dump_tags}.tgz")
          expect(File).to receive(:file?).with(path).at_least(1).and_return(true)
          path
        end
        allow(Dir).to receive(:[]).and_return(paths)
      end

      it 'should return all dumps if no tags send' do
        expect(DumpRake::Snapshot.list(:tags => '')).to eq(DumpRake::Snapshot.list)
      end

      {
        'x'           => [],
        '+x'          => [],
        'z'           => [16],
        'a,d,s,o'     => [1..15],
        '+a,+d,+s,+o' => [5],
        '-o'          => [0, 1, 2, 4, 7, 9, 11, 14, 16],
        'a,b,c,+s,-o' => [4, 7],
        '+a,+d'          => [2, 3, 4, 5],
        '+d,+a'          => [2, 3, 4, 5],
      }.each do |tags, ids|
        it "should return dumps filtered by #{tags}" do
          expect(DumpRake::Snapshot.list(:tags => tags)).to eq(DumpRake::Snapshot.list.values_at(*ids))
        end
      end
    end
  end

  describe 'name' do
    it 'should return file name' do
      expect(new_dump('19650414065945.tgz').name).to eq('19650414065945.tgz')
    end
  end

  describe 'parts' do
    before do
      @time = Time.utc(1965, 4, 14, 6, 59, 45)
    end

    def dump_name_parts(name)
      dump = new_dump(name)
      [dump.time, dump.description, dump.tags, dump.ext]
    end

    %w[tmp tgz].each do |ext|
      it 'should return empty results for dump with wrong name' do
        expect(dump_name_parts("196504140659.#{ext}")).to eq([nil, '', [], nil])
        expect(dump_name_parts("196504140659-lala.#{ext}")).to eq([nil, '', [], nil])
        expect(dump_name_parts("196504140659@lala.#{ext}")).to eq([nil, '', [], nil])
        expect(dump_name_parts('19650414065945.ops')).to eq([nil, '', [], nil])
      end

      it 'should return tags for dump with tags' do
        expect(dump_name_parts("19650414065945.#{ext}")).to eq([@time, '', [], ext])
        expect(dump_name_parts("19650414065945- Hello world &&& .#{ext}")).to eq([@time, 'Hello world _', [], ext])
        expect(dump_name_parts("19650414065945- Hello world &&& @ test , hello world , bad tag ~~~~.#{ext}")).to eq([@time, 'Hello world _', ['bad tag _', 'hello world', 'test'], ext])
        expect(dump_name_parts("19650414065945@test, test , hello world , bad tag ~~~~.#{ext}")).to eq([@time, '', ['bad tag _', 'hello world', 'test'], ext])
        expect(dump_name_parts("19650414065945-Hello world@test,super tag.#{ext}")).to eq([@time, 'Hello world', ['super tag', 'test'], ext])
      end
    end
  end

  describe 'path' do
    it 'should return path' do
      expect(new_dump('19650414065945.tgz').path).to eq(Pathname(File.join(DumpRake::RailsRoot, 'dump', '19650414065945.tgz')))
    end
  end

  describe 'tgz_path' do
    it 'should return path if extension is already tgz' do
      expect(new_dump('19650414065945.tgz').tgz_path).to eq(new_dump('19650414065945.tgz').path)
    end

    it 'should return path with tgz extension' do
      expect(new_dump('19650414065945.tmp').tgz_path).to eq(new_dump('19650414065945.tgz').path)
    end
  end

  describe 'tmp_path' do
    it 'should return path if extension is already tmp' do
      expect(new_dump('19650414065945.tmp').tmp_path).to eq(new_dump('19650414065945.tmp').path)
    end

    it 'should return path with tmp extension' do
      expect(new_dump('19650414065945.tgz').tmp_path).to eq(new_dump('19650414065945.tmp').path)
    end
  end

  describe 'clean_description' do
    it "should shorten string to 50 chars and replace special symblos with '-'" do
      expect(DumpRake::Snapshot.new('').send(:clean_description, 'Special  Dump #12837192837 (before fixind *&^*&^ photos)')).to eq('Special Dump #12837192837 (before fixind _ photos)')
      expect(DumpRake::Snapshot.new('').send(:clean_description, "To#{'o' * 100} long description")).to eq("T#{'o' * 49}")
    end

    it 'should accept non string' do
      expect(DumpRake::Snapshot.new('').send(:clean_description, nil)).to eq('')
    end
  end

  describe 'clean_tag' do
    it "should shorten string to 20 chars and replace special symblos with '-'" do
      expect(DumpRake::Snapshot.new('').send(:clean_tag, 'Very special  tag #12837192837 (fixind *&^*&^)')).to eq('very special tag _12')
      expect(DumpRake::Snapshot.new('').send(:clean_tag, "To#{'o' * 100} long tag")).to eq("t#{'o' * 19}")
    end

    it "should not allow '-' or '+' to be first symbol" do
      expect(DumpRake::Snapshot.new('').send(:clean_tag, ' Very special tag')).to eq('very special tag')
      expect(DumpRake::Snapshot.new('').send(:clean_tag, '-Very special tag')).to eq('very special tag')
      expect(DumpRake::Snapshot.new('').send(:clean_tag, '-----------')).to eq('')
      expect(DumpRake::Snapshot.new('').send(:clean_tag, '+Very special tag')).to eq('_very special tag')
      expect(DumpRake::Snapshot.new('').send(:clean_tag, '+++++++++++')).to eq('_')
    end

    it 'should accept non string' do
      expect(DumpRake::Snapshot.new('').send(:clean_tag, nil)).to eq('')
    end
  end

  describe 'clean_tags' do
    it 'should split string and return uniq non blank sorted tags' do
      expect(DumpRake::Snapshot.new('').send(:clean_tags, ' perfect  tag , hello,Hello,this  is (*^(*&')).to eq(['hello', 'perfect tag', 'this is _'])
      expect(DumpRake::Snapshot.new('').send(:clean_tags, "l#{'o' * 100}ng tag")).to eq(["l#{'o' * 19}"])
    end

    it 'should accept non string' do
      expect(DumpRake::Snapshot.new('').send(:clean_tags, nil)).to eq([])
    end
  end

  describe 'get_filter_tags' do
    it 'should split string and return uniq non blank sorted tags' do
      expect(DumpRake::Snapshot.new('').send(:get_filter_tags, 'a,+b,+c,-d')).to eq({:simple => %w[a], :mandatory => %w[b c], :forbidden => %w[d]})
      expect(DumpRake::Snapshot.new('').send(:get_filter_tags, ' a , + b , + c , - d ')).to eq({:simple => %w[a], :mandatory => %w[b c], :forbidden => %w[d]})
      expect(DumpRake::Snapshot.new('').send(:get_filter_tags, ' a , + c , + b , - d ')).to eq({:simple => %w[a], :mandatory => %w[b c], :forbidden => %w[d]})
      expect(DumpRake::Snapshot.new('').send(:get_filter_tags, ' a , + b , + , - ')).to eq({:simple => %w[a], :mandatory => %w[b], :forbidden => []})
      expect(DumpRake::Snapshot.new('').send(:get_filter_tags, ' a , a , + b , + b , - d , - d ')).to eq({:simple => %w[a], :mandatory => %w[b], :forbidden => %w[d]})
      expect{ DumpRake::Snapshot.new('').send(:get_filter_tags, 'a,+a') }.not_to raise_error
      expect{ DumpRake::Snapshot.new('').send(:get_filter_tags, 'a,-a') }.to raise_error
      expect{ DumpRake::Snapshot.new('').send(:get_filter_tags, '+a,-a') }.to raise_error
    end

    it 'should accept non string' do
      expect(DumpRake::Snapshot.new('').send(:get_filter_tags, nil)).to eq({:simple => [], :mandatory => [], :forbidden => []})
    end
  end

  describe 'assets_root_link' do
    it 'should create tem dir, chdir there, symlink rails app root to assets, yield and unlink assets ever if something raised' do
      expect(Dir).to receive(:mktmpdir).and_yield('/tmp/abc')
      expect(Dir).to receive(:chdir).with('/tmp/abc').and_yield
      expect(File).to receive(:symlink).with(DumpRake::RailsRoot, 'assets')
      expect(File).to receive(:unlink).with('assets')
      expect do
        DumpRake::Snapshot.new('').send(:assets_root_link) do |dir, prefix|
          expect(dir).to eq('/tmp/abc')
          expect(prefix).to eq('assets')
          @yielded = true
          fail 'just test'
        end
      end.to raise_error('just test')
      expect(@yielded).to eq(true)
    end
  end
end
