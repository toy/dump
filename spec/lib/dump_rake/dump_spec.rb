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
        Dump.new(:dir => 'dump_dir', :description => 'hello world').path.should == Pathname('dump_dir/19650414000000-hello-world.tgz')
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

  describe "with_env" do
    it "should set env to new_value for duration of block" do
      ENV['TESTING'] = 'old_value'

      ENV['TESTING'].should == 'old_value'
      Dump.new('').send(:with_env, 'TESTING', 'new_value') do
        ENV['TESTING'].should == 'new_value'
      end
      ENV['TESTING'].should == 'old_value'
    end
  end

  describe "clean_description" do
    it "should shorten string to 30 chars and replace all symbols except a-z and 0-9 with '-'" do
      Dump.new('').send(:clean_description, 'aenarhts ENHENH 12837192837 #$@#^%%^^%*&(*& arsth *&^*&^ ahrenst haenr sheanrs heran t').should == 'aenarhts-enhenh-12837192837-ar'
    end

    it "should accept non string" do
      Dump.new('').send(:clean_description, nil).should == ''
    end
  end
end
