require File.dirname(__FILE__) + '/../../spec_helper'

Dump = DumpRake::Dump
describe Dump do
  def dump_path(file_name)
    File.join(RAILS_ROOT, 'dump', file_name)
  end

  def new_dump(file_name)
    Dump.new(dump_path(file_name))
  end

  describe "lock" do
    before do
      @yield_receiver = mock('yield_receiver')
    end

    it "should not yield if file does not exist" do
      @yield_receiver.should_not_receive(:fire)

      File.should_receive(:open).and_return(nil)

      Dump.new('hello').lock do
        @yield_receiver.fire
      end
    end

    it "should not yield if file can not be locked" do
      @yield_receiver.should_not_receive(:fire)

      @file = mock('file')
      @file.should_receive(:flock).with(File::LOCK_EX | File::LOCK_NB).and_return(nil)
      @file.should_receive(:flock).with(File::LOCK_UN)
      @file.should_receive(:close)
      File.should_receive(:open).and_return(@file)

      Dump.new('hello').lock do
        @yield_receiver.fire
      end
    end

    it "should yield if file can not be locked" do
      @yield_receiver.should_receive(:fire)

      @file = mock('file')
      @file.should_receive(:flock).with(File::LOCK_EX | File::LOCK_NB).and_return(true)
      @file.should_receive(:flock).with(File::LOCK_UN)
      @file.should_receive(:close)
      File.should_receive(:open).and_return(@file)

      Dump.new('hello').lock do
        @yield_receiver.fire
      end
    end
  end

  describe "new" do
    it "should init with path if String sent" do
      Dump.new('hello').path.should == Pathname('hello')
    end

    it "should init with path if Pathname sent" do
      Dump.new(Pathname('hello')).path.should == Pathname('hello')
    end

    describe "with options" do
      before do
        @time = mock('time')
        @time.stub!(:utc).and_return(@time)
        @time.stub!(:strftime).and_return('19650414065945')
        Time.stub!(:now).and_return(@time)
      end

      it "should generate path with no options" do
        Dump.new.path.should == Pathname('19650414065945.tgz')
      end

      it "should generate with dir" do
        Dump.new(:dir => 'dump_dir').path.should == Pathname('dump_dir/19650414065945.tgz')
      end

      it "should generate path with description" do
        Dump.new(:dir => 'dump_dir', :desc => 'hello world').path.should == Pathname('dump_dir/19650414065945-hello world.tgz')
      end

      it "should generate path with tags" do
        Dump.new(:dir => 'dump_dir', :tags => ' mirror, hello world ').path.should == Pathname('dump_dir/19650414065945@hello world,mirror.tgz')
      end

      it "should generate path with description and tags" do
        Dump.new(:dir => 'dump_dir', :desc => 'Anniversary backup', :tags => ' mirror, hello world ').path.should == Pathname('dump_dir/19650414065945-Anniversary backup@hello world,mirror.tgz')
      end
    end
  end

  describe "versions" do
    describe "list" do
      def stub_glob
        paths = %w(123 345 567).map do |name|
          path = dump_path("#{name}.tgz")
          File.should_receive(:file?).with(path).at_least(1).and_return(true)
          path
        end
        Dir.stub!(:[]).and_return(paths)
      end

      it "should search for files in dump dir when asked for list" do
        Dir.should_receive(:[]).with(dump_path('*.tgz')).and_return([])
        Dump.list
      end

      it "should return selves instances for each found file" do
        stub_glob
        Dump.list.all?{ |dump| dump.should be_a(Dump) }
      end

      it "should return dumps with name containting :like" do
        stub_glob
        Dump.list(:like => '3').should == Dump.list.values_at(0, 1)
      end
    end

    describe "with tags" do
      before do
        #             0        1  2    3      4      5        6    7    8      9  10   11   12     13 14 15   16
        dumps_tags = [''] + %w(a  a,d  a,d,o  a,d,s  a,d,s,o  a,o  a,s  a,s,o  d  d,o  d,s  d,s,o  o  s  s,o  z)
        paths = dumps_tags.enum_with_index.map do |dump_tags, i|
          path = dump_path("196504140659#{10 + i}@#{dump_tags}.tgz")
          File.should_receive(:file?).with(path).at_least(1).and_return(true)
          path
        end
        Dir.stub!(:[]).and_return(paths)
      end

      it "should return all dumps if no tags send" do
        Dump.list(:tags => '').should == Dump.list
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
          Dump.list(:tags => tags).should == Dump.list.values_at(*ids)
        end
      end
    end
  end

  describe "name" do
    it "should return file name" do
      new_dump("19650414065945.tgz").name.should == '19650414065945.tgz'
    end
  end

  describe "parts" do
    before do
      @time = Time.utc(1965, 4, 14, 6, 59, 45)
    end

    def dump_name_parts(name)
      dump = new_dump(name)
      [dump.time, dump.description, dump.tags, dump.ext]
    end

    %w(tmp tgz).each do |ext|
      it "should return empty results for dump with wrong name" do
        dump_name_parts("196504140659.#{ext}").should == [nil, '', [], nil]
        dump_name_parts("196504140659-lala.#{ext}").should == [nil, '', [], nil]
        dump_name_parts("196504140659@lala.#{ext}").should == [nil, '', [], nil]
        dump_name_parts("19650414065945.ops").should == [nil, '', [], nil]
      end

      it "should return tags for dump with tags" do
        dump_name_parts("19650414065945.#{ext}").should == [@time, '', [], ext]
        dump_name_parts("19650414065945- Hello world &&& .#{ext}").should == [@time, 'Hello world _', [], ext]
        dump_name_parts("19650414065945- Hello world &&& @ test , hello world , bad tag ~~~~.#{ext}").should == [@time, 'Hello world _', ['bad tag _', 'hello world', 'test'], ext]
        dump_name_parts("19650414065945@test, test , hello world , bad tag ~~~~.#{ext}").should == [@time, '', ['bad tag _', 'hello world', 'test'], ext]
        dump_name_parts("19650414065945-Hello world@test,super tag.#{ext}").should == [@time, 'Hello world', ['super tag', 'test'], ext]
      end
    end
  end

  describe "path" do
    it "should return path" do
      new_dump("19650414065945.tgz").path.should == Pathname(File.join(RAILS_ROOT, 'dump', "19650414065945.tgz"))
    end
  end

  describe "tgz_path" do
    it "should return path if extension is already tgz" do
      new_dump("19650414065945.tgz").tgz_path.should == new_dump("19650414065945.tgz").path
    end

    it "should return path with tgz extension" do
      new_dump("19650414065945.tmp").tgz_path.should == new_dump("19650414065945.tgz").path
    end
  end

  describe "tmp_path" do
    it "should return path if extension is already tmp" do
      new_dump("19650414065945.tmp").tmp_path.should == new_dump("19650414065945.tmp").path
    end

    it "should return path with tmp extension" do
      new_dump("19650414065945.tgz").tmp_path.should == new_dump("19650414065945.tmp").path
    end
  end

  describe "verify_connection" do
    it "should return result of ActiveRecord::Base.connection.verify!" do
      ActiveRecord::Base.connection.should_receive(:verify!).and_return(:result)
      Dump.new('').send(:verify_connection).should == :result
    end
  end

  describe "quote_table_name" do
    it "should return result of ActiveRecord::Base.connection.quote_table_name" do
      ActiveRecord::Base.connection.should_receive(:quote_table_name).with('first').and_return('`first`')
      Dump.new('').send(:quote_table_name, 'first').should == '`first`'
    end
  end

  describe "clean_description" do
    it "should shorten string to 50 chars and replace special symblos with '-'" do
      Dump.new('').send(:clean_description, 'Special  Dump #12837192837 (before fixind *&^*&^ photos)').should == 'Special Dump #12837192837 (before fixind _ photos)'
      Dump.new('').send(:clean_description, "To#{'o' * 100} long description").should == "T#{'o' * 49}"
    end

    it "should accept non string" do
      Dump.new('').send(:clean_description, nil).should == ''
    end
  end

  describe "clean_tag" do
    it "should shorten string to 20 chars and replace special symblos with '-'" do
      Dump.new('').send(:clean_tag, 'Very special  tag #12837192837 (fixind *&^*&^)').should == 'very special tag _12'
      Dump.new('').send(:clean_tag, "To#{'o' * 100} long tag").should == "t#{'o' * 19}"
    end

    it "should not allow '-' or '+' to be first symbol" do
      Dump.new('').send(:clean_tag, ' Very special tag').should == 'very special tag'
      Dump.new('').send(:clean_tag, '-Very special tag').should == 'very special tag'
      Dump.new('').send(:clean_tag, '-----------').should == ''
      Dump.new('').send(:clean_tag, '+Very special tag').should == '_very special tag'
      Dump.new('').send(:clean_tag, '+++++++++++').should == '_'
    end

    it "should accept non string" do
      Dump.new('').send(:clean_tag, nil).should == ''
    end
  end

  describe "clean_tags" do
    it "should split string and return uniq non blank sorted tags" do
      Dump.new('').send(:clean_tags, ' perfect  tag , hello,Hello,this  is (*^(*&').should == ['hello', 'perfect tag', 'this is _']
      Dump.new('').send(:clean_tags, "l#{'o' * 100}ng tag").should == ["l#{'o' * 19}"]
    end

    it "should accept non string" do
      Dump.new('').send(:clean_tags, nil).should == []
    end
  end

  describe "get_filter_tags" do
    it "should split string and return uniq non blank sorted tags" do
      Dump.new('').send(:get_filter_tags, 'a,+b,+c,-d').should == {:simple => %w(a), :mandatory => %w(b c), :forbidden => %w(d)}
      Dump.new('').send(:get_filter_tags, ' a , + b , + c , - d ').should == {:simple => %w(a), :mandatory => %w(b c), :forbidden => %w(d)}
      Dump.new('').send(:get_filter_tags, ' a , + c , + b , - d ').should == {:simple => %w(a), :mandatory => %w(b c), :forbidden => %w(d)}
      Dump.new('').send(:get_filter_tags, ' a , + b , + , - ').should == {:simple => %w(a), :mandatory => %w(b), :forbidden => []}
      Dump.new('').send(:get_filter_tags, ' a , a , + b , + b , - d , - d ').should == {:simple => %w(a), :mandatory => %w(b), :forbidden => %w(d)}
      proc{ Dump.new('').send(:get_filter_tags, 'a,+a') }.should_not raise_error
      proc{ Dump.new('').send(:get_filter_tags, 'a,-a') }.should raise_error
      proc{ Dump.new('').send(:get_filter_tags, '+a,-a') }.should raise_error
    end

    it "should accept non string" do
      Dump.new('').send(:get_filter_tags, nil).should == {:simple => [], :mandatory => [], :forbidden => []}
    end
  end

  describe "schema_tables" do
    it "should return schema_tables" do
      Dump.new('').send(:schema_tables).should == %w(schema_info schema_migrations)
    end
  end
end
