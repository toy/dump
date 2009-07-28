require File.dirname(__FILE__) + '/../../spec_helper'

Dump = DumpRake::Dump
describe Dump do
  def dump_path(file_name)
    File.join(RAILS_ROOT, 'dump', file_name)
  end

  def new_dump(file_name)
    Dump.new(dump_path(file_name))
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
        @time.stub!(:strftime).and_return('19650414000000')
        Time.stub!(:now).and_return(@time)
      end

      it "should generate path with no options" do
        Dump.new.path.should == Pathname('19650414000000.tgz')
      end

      it "should generate with dir" do
        Dump.new(:dir => 'dump_dir').path.should == Pathname('dump_dir/19650414000000.tgz')
      end

      it "should generate path with description" do
        Dump.new(:dir => 'dump_dir', :desc => 'hello world').path.should == Pathname('dump_dir/19650414000000-hello world.tgz')
      end

      it "should generate path with tags" do
        Dump.new(:dir => 'dump_dir', :tags => ' mirror, hello world ').path.should == Pathname('dump_dir/19650414000000@hello world@mirror.tgz')
      end

      it "should generate path with description and tags" do
        Dump.new(:dir => 'dump_dir', :desc => 'Anniversary backup', :tags => ' mirror, hello world ').path.should == Pathname('dump_dir/19650414000000-Anniversary backup@hello world@mirror.tgz')
      end
    end
  end

  describe "versions" do
    def stub_glob
      Dir.stub!(:[]).and_return(%w(123 345 567).map{ |name| dump_path("#{name}.tgz")})
    end

    describe "list" do
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
        Dump.list(:like => '3').should == [Dump.list[0], Dump.list[1]]
      end
    end
  end

  describe "name" do
    it "should return file name" do
      new_dump("123.tgz").name.should == '123.tgz'
    end
  end

  describe "path" do
    it "should return path" do
      new_dump("123.tgz").path.should == Pathname(File.join(RAILS_ROOT, 'dump', "123.tgz"))
    end
  end

  describe "tgz_path" do
    it "should return path if extension is already tgz" do
      new_dump("123.tgz").tgz_path.should == new_dump("123.tgz").path
    end

    it "should return path with tgz extension" do
      new_dump("123.tmp").tgz_path.should == new_dump("123.tgz").path
    end
  end

  describe "tmp_path" do
    it "should return path if extension is already tmp" do
      new_dump("123.tmp").tmp_path.should == new_dump("123.tmp").path
    end

    it "should return path with tmp extension" do
      new_dump("123.tgz").tmp_path.should == new_dump("123.tmp").path
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
end
