require File.dirname(__FILE__) + '/../../spec_helper'

Dump = DumpRake::Dump
describe Dump do
  describe "versions" do
    def stub_glob
      Dir.stub!(:glob).and_return(%w(123 345 567).map{ |name| File.join(RAILS_ROOT, 'dump', "#{name}.tgz")})
    end

    describe "list" do
      it "should search for files in dump dir when asked for list" do
        Dir.should_receive(:glob).with(File.join(RAILS_ROOT, 'dump', '*.tgz')).and_return([])
        Dump.list
      end

      it "should return selves instances for each found file" do
        stub_glob
        Dump.list.all?{ |dump| dump.should be_a(Dump) }
      end
    end

    describe "last" do
      it "should return last dump in list" do
        stub_glob
        Dump.last.should == Dump.list.last
      end
    end

    describe "like" do
      it "should return dumps with name containting argument" do
        stub_glob
        Dump.like('3').should == [Dump.list[0], Dump.list[1]]
      end
    end
  end

  describe "name" do
    it "should return file name" do
      Dump.new(File.join(RAILS_ROOT, 'dump', "123.tgz")).name.should == '123.tgz'
    end
  end
end
