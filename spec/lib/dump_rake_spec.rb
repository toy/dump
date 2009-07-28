require File.dirname(__FILE__) + '/../spec_helper'

describe DumpRake do
  describe "versions" do
    it "should call Dump.list if called without version" do
      DumpRake::Dump.should_receive(:list).and_return([])
      DumpRake.versions
    end

    it "should call Dump.list with options if called with version" do
      DumpRake::Dump.should_receive(:list).with(:like => '123').and_return([])
      DumpRake.versions(:like => '123')
    end

    it "should print versions" do
      DumpRake::Dump.should_receive(:list).and_return(%w(123.tgz 456.tgz))
      grab_output{
        DumpRake.versions
      }[:stdout].should == "123.tgz\n456.tgz\n"
    end
  end

  describe "create" do
    describe "naming" do
      it "should create file in RAILS_ROOT/dump" do
        File.stub!(:rename)
        DumpRake::DumpWriter.should_receive(:create) do |path|
          File.dirname(path).should == File.join(RAILS_ROOT, 'dump')
        end
        grab_output{
          DumpRake.create
        }
      end

      it "should create file with name like yyyymmddhhmmss.tmp when called without description" do
        File.stub!(:rename)
        DumpRake::DumpWriter.should_receive(:create) do |path|
          File.basename(path).should match(/^\d{14}\.tmp$/)
        end
        grab_output{
          DumpRake.create
        }
      end

      it "should create file with name like yyyymmddhhmmss-some-text-and.tmp when called with description Some text and !@" do
        File.stub!(:rename)
        DumpRake::DumpWriter.should_receive(:create) do |path|
          File.basename(path).should match(/^\d{14}-Some text and _\.tmp$/)
        end
        grab_output{
          DumpRake.create(:desc => 'Some text and !@')
        }
      end

      it "should rename file after creating" do
        File.should_receive(:rename) do |tmp_path, tgz_path|
          File.basename(tmp_path).should match(/^\d{14}-Some text and _\.tmp$/)
          File.basename(tgz_path).should match(/^\d{14}-Some text and _\.tgz$/)
        end
        DumpRake::DumpWriter.stub!(:create)
        grab_output{
          DumpRake.create(:desc => 'Some text and !@')
        }
      end

      it "should output file name" do
        File.stub!(:rename)
        DumpRake::DumpWriter.stub!(:create)
        grab_output{
          DumpRake.create(:desc => 'Some text and !@')
        }[:stdout].should match(/^\d{14}-Some text and _\.tgz$/)
      end
    end

    describe "writing" do
      it "should dump schema, tables, assets" do
        File.stub!(:rename)
        @dump = mock('dump')
        DumpRake::DumpWriter.should_receive(:create)

        grab_output{
          DumpRake.create
        }
      end
    end
  end

  describe "restore" do
    describe "without version" do
      it "should call Dump.list" do
        DumpRake::Dump.should_receive(:list).and_return([])
        DumpRake.stub!(:versions)
        grab_output{
          DumpRake.restore
        }
      end

      it "should not call DumpReader.restore and should call versions if there are no versions at all" do
        DumpRake::Dump.stub!(:list).and_return([])
        DumpRake::DumpReader.should_not_receive(:restore)
        DumpRake.should_receive(:versions)
        grab_output{
          DumpRake.restore
        }
      end

      it "should not call DumpReader.restore and should call versions if there are no versions at all" do
        DumpRake::Dump.stub!(:list).and_return([])
        DumpRake::DumpReader.should_not_receive(:restore)
        DumpRake.should_receive(:versions)
        grab_output{
          DumpRake.restore('213')
        }
      end

      it "should call DumpReader.restore if there are versions" do
        @dump = mock('dump', :path => 'dump/213.tgz')
        DumpRake::Dump.stub!(:list).and_return([@dump])
        DumpRake::DumpReader.should_receive(:restore).with('dump/213.tgz')
        DumpRake.should_not_receive(:versions)
        grab_output{
          DumpRake.restore
        }
      end
    end

    describe "with version" do
      it "should call Dump.list with options" do
        DumpRake::Dump.should_receive(:list).with(:like => '213').and_return([])
        DumpRake.stub!(:versions)
        grab_output{
          DumpRake.restore(:like => '213')
        }
      end

      it "should not call DumpReader.restore and should call versions if desired version not found" do
        DumpRake::Dump.stub!(:list).and_return([])
        DumpRake::DumpReader.should_not_receive(:restore)
        DumpRake.should_receive(:versions)
        grab_output{
          DumpRake.restore('213')
        }
      end

      it "should call DumpReader.restore if there is desired version" do
        @dump = mock('dump', :path => 'dump/213.tgz')
        DumpRake::Dump.stub!(:list).and_return([@dump])
        DumpRake::DumpReader.should_receive(:restore).with('dump/213.tgz')
        DumpRake.should_not_receive(:versions)
        grab_output{
          DumpRake.restore(:like => '213')
        }
      end

      it "should call DumpReader.restore on last version if found multiple matching versions" do
        @dump_a = mock('dump_a', :path => 'dump/213-a.tgz')
        @dump_b = mock('dump_b', :path => 'dump/213-b.tgz')
        DumpRake::Dump.stub!(:list).and_return([@dump_a, @dump_b])
        DumpRake::DumpReader.should_receive(:restore).with('dump/213-b.tgz')
        DumpRake.should_not_receive(:versions)
        grab_output{
          DumpRake.restore(:like => '213')
        }
      end

    end
  end
end