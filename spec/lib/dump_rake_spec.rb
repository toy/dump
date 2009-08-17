require File.dirname(__FILE__) + '/../spec_helper'

describe DumpRake do
  describe "require_gem_or_unpacked_gem" do
    before do
      def gem(*args)
        @expectations.gem(*args)
      end
      def require(*args)
        @expectations.require(*args)
      end
      @expectations = mock('expectations')
    end

    it "should not use unpacked, should not call gem and should call require when called without version" do
      @expectations.should_not_receive(:gem)
      @expectations.should_receive(:require).with('progress')
      $:.should_not_receive(:<<)

      require_gem_or_unpacked_gem('progress')
    end

    it "should not use unpacked, should call gem and should call require when called with version" do
      @expectations.should_receive(:gem).with('progress', '1.2.3')
      @expectations.should_receive(:require).with('progress')
      $:.should_not_receive(:<<)

      require_gem_or_unpacked_gem('progress', '1.2.3')
    end

    it "should use unpacked, should not call gem and should call require when called without version and require fails" do
      @expectations.should_not_receive(:gem)
      @expectations.should_receive(:require).with('progress').and_raise(MissingSourceFile.new('', ''))
      $:.should_receive(:<<).with(instance_of(Pathname))
      @expectations.should_receive(:require).with('progress')

      require_gem_or_unpacked_gem('progress')
    end

    it "should use unpacked, should call gem and should not call require when called with version and gem fails" do
      @expectations.should_receive(:gem).with('progress', '1.2.3').and_raise(Gem::LoadError)
      $:.should_receive(:<<).with(instance_of(Pathname))
      @expectations.should_receive(:require).with('progress')

      require_gem_or_unpacked_gem('progress', '1.2.3')
    end

    it "should use unpacked, should call gem and should call require when called with version and require fails" do
      @expectations.should_receive(:gem).with('progress', '1.2.3')
      @expectations.should_receive(:require).with('progress').and_raise(MissingSourceFile.new('', ''))
      $:.should_receive(:<<).with(instance_of(Pathname))
      @expectations.should_receive(:require).with('progress')

      require_gem_or_unpacked_gem('progress', '1.2.3')
    end
  end

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

    it "should not show summary if not asked for" do
      dumps = %w(123.tgz 456.tgz).map do |s|
        dump = mock("dump_#{s}", :path => mock("dump_#{s}_path"))
        DumpRake::DumpReader.should_not_receive(:summary)
        dump
      end

      DumpRake::Dump.should_receive(:list).and_return(dumps)
      grab_output{
        $stderr.should_not_receive(:puts)
        DumpRake.versions
      }
    end

    it "should show summary if asked for" do
      dumps = %w(123.tgz 456.tgz).map do |s|
        dump = mock("dump_#{s}", :path => mock("dump_#{s}_path"))
        DumpRake::DumpReader.should_receive(:summary).with(dump.path)
        dump
      end

      DumpRake::Dump.should_receive(:list).and_return(dumps)
      grab_output{
        $stderr.should_not_receive(:puts)
        DumpRake.versions(:summary => 'true')
      }
    end

    it "should show summary with scmema if asked for" do
      dumps = %w(123.tgz 456.tgz).map do |s|
        dump = mock("dump_#{s}", :path => mock("dump_#{s}_path"))
        DumpRake::DumpReader.should_receive(:summary).with(dump.path, :schema => true)
        dump
      end

      DumpRake::Dump.should_receive(:list).and_return(dumps)
      grab_output{
        $stderr.should_not_receive(:puts)
        DumpRake.versions(:summary => 'full')
      }
    end

    it "should show output to stderr if summary raises error" do
      DumpRake::DumpReader.stub!(:summary)
      dumps = %w(123.tgz 456.tgz).map do |s|
        mock("dump_#{s}", :path => mock("dump_#{s}_path"))
      end
      DumpRake::DumpReader.should_receive(:summary).with(dumps[1].path).and_raise('terrible error')

      DumpRake::Dump.should_receive(:list).and_return(dumps)
      grab_output{
        $stderr.stub!(:puts)
        $stderr.should_receive(:puts) do |s|
          s['terrible error'].should_not be_nil
        end
        DumpRake.versions(:summary => 'true')
      }
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

      it "should create file with name like 'yyyymmddhhmmss.tmp' when called without description" do
        File.stub!(:rename)
        DumpRake::DumpWriter.should_receive(:create) do |path|
          File.basename(path).should match(/^\d{14}\.tmp$/)
        end
        grab_output{
          DumpRake.create
        }
      end

      it "should create file with name like 'yyyymmddhhmmss-Some text and _.tmp' when called with description 'Some text and !@'" do
        File.stub!(:rename)
        DumpRake::DumpWriter.should_receive(:create) do |path|
          File.basename(path).should match(/^\d{14}-Some text and _\.tmp$/)
        end
        grab_output{
          DumpRake.create(:desc => 'Some text and !@')
        }
      end

      it "should create file with name like 'yyyymmddhhmmss@super tag,second.tmp' when called with description 'Some text and !@'" do
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
        DumpRake::Dump.stub!(:list)
        DumpRake::Dump.should_receive(:list).and_return([])
        grab_output{
          DumpRake.restore
        }
      end

      it "should not call DumpReader.restore and should call Dump.list and output it to $stderr if there are no versions at all" do
        DumpRake::Dump.stub!(:list).and_return([])
        DumpRake::DumpReader.should_not_receive(:restore)
        all_dumps = mock('all_dumps')
        DumpRake::Dump.should_receive(:list).with().and_return(all_dumps)
        grab_output{
          $stderr.should_receive(:puts).with(kind_of(String))
          $stderr.should_receive(:puts).with(all_dumps)
          DumpRake.restore
        }
      end

      it "should not call DumpReader.restore and should call Dump.list and output it to $stderr if there are no versions at all" do
        DumpRake::Dump.stub!(:list).and_return([])
        DumpRake::DumpReader.should_not_receive(:restore)
        all_dumps = mock('all_dumps')
        DumpRake::Dump.should_receive(:list).with().and_return(all_dumps)
        grab_output{
          $stderr.should_receive(:puts).with(kind_of(String))
          $stderr.should_receive(:puts).with(all_dumps)
          DumpRake.restore('213')
        }
      end

      it "should call DumpReader.restore if there are versions" do
        @dump = mock('dump', :path => 'dump/213.tgz')
        DumpRake::Dump.should_receive(:list).once.and_return([@dump])
        DumpRake::DumpReader.should_receive(:restore).with('dump/213.tgz')
        grab_output{
          $stderr.should_not_receive(:puts)
          DumpRake.restore
        }
      end
    end

    describe "with version" do
      it "should call Dump.list with options" do
        DumpRake::Dump.stub!(:list)
        DumpRake::Dump.should_receive(:list).with(:like => '213').and_return([])
        grab_output{
          DumpRake.restore(:like => '213')
        }
      end

      it "should not call DumpReader.restore and should call versions if desired version not found" do
        DumpRake::Dump.stub!(:list).and_return([])
        DumpRake::DumpReader.should_not_receive(:restore)
        all_dumps = mock('all_dumps')
        DumpRake::Dump.should_receive(:list).with().and_return(all_dumps)
        grab_output{
          $stderr.should_receive(:puts).with(kind_of(String))
          $stderr.should_receive(:puts).with(all_dumps)
          DumpRake.restore('213')
        }
      end

      it "should call DumpReader.restore if there is desired version" do
        @dump = mock('dump', :path => 'dump/213.tgz')
        DumpRake::Dump.should_receive(:list).once.and_return([@dump])
        DumpRake::DumpReader.should_receive(:restore).with('dump/213.tgz')
        DumpRake.should_not_receive(:versions)
        grab_output{
          $stderr.should_not_receive(:puts)
          DumpRake.restore(:like => '213')
        }
      end

      it "should call DumpReader.restore on last version if found multiple matching versions" do
        @dump_a = mock('dump_a', :path => 'dump/213-a.tgz')
        @dump_b = mock('dump_b', :path => 'dump/213-b.tgz')
        DumpRake::Dump.should_receive(:list).once.and_return([@dump_a, @dump_b])
        DumpRake::DumpReader.should_receive(:restore).with('dump/213-b.tgz')
        grab_output{
          $stderr.should_not_receive(:puts)
          DumpRake.restore(:like => '213')
        }
      end
    end
  end

  describe "cleanup" do
    it "should call ask for all files in dump dir and for dumps" do
      DumpRake::Dump.should_receive(:list).with(:all => true).and_return([])
      DumpRake::Dump.should_receive(:list).with({}).and_return([])
      DumpRake.cleanup
    end

    it "should call Dump.list with options if called with version and tags" do
      DumpRake::Dump.should_receive(:list).with(:like => '123', :tags => 'a,b,c', :all => true).and_return([])
      DumpRake::Dump.should_receive(:list).with(:like => '123', :tags => 'a,b,c').and_return([])
      DumpRake.cleanup(:like => '123', :tags => 'a,b,c')
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
      it "should call delete #{ids} dumps when called with #{options}" do
        dumps = %w(a b c d e f g h i j).map do |s|
          mock("dump_#{s}", :ext => 'tgz', :path => mock("dump_#{s}_path"))
        end
        tmp_dumps = %w(a b c).map do |s|
          mock("tmp_dump_#{s}", :ext => 'tmp', :path => mock("tmp_dump_#{s}_path"))
        end
        all_dumps = tmp_dumps[0, 1] + dumps[0, 5] + tmp_dumps[1, 1] + dumps[5, 5] + tmp_dumps[2, 1]

        (dumps.values_at(*ids) + [tmp_dumps[0], tmp_dumps[2]]).each do |dump|
          dump.should_receive(:lock).and_yield
          dump.path.should_receive(:unlink)
        end
        [tmp_dumps[1]].each do |dump|
          dump.should_receive(:lock)
          dump.path.should_not_receive(:unlink)
        end
        (dumps - dumps.values_at(*ids)).each do |dump|
          dump.should_not_receive(:lock)
          dump.path.should_not_receive(:unlink)
        end

        DumpRake::Dump.should_receive(:list).with(hash_including(:all => true)).and_return(all_dumps)
        DumpRake::Dump.should_receive(:list).with(hash_not_including(:all => true)).and_return(dumps)
        grab_output{
          DumpRake.cleanup({:like => '123', :tags => 'a,b,c'}.merge(options))
        }
      end
    end

    it "should print to stderr if can not delete dump" do
      dumps = %w(a b c d e f g h i j).map do |s|
        dump = mock("dump_#{s}", :ext => 'tgz', :path => mock("dump_#{s}_path"))
        dump.stub!(:lock).and_yield
        dump.path.stub!(:unlink)
        dump
      end

      dumps[3].path.should_receive(:unlink).and_raise('Horrible error')

      DumpRake::Dump.stub!(:list).and_return(dumps)
      grab_output{
        $stderr.stub!(:puts)
        $stderr.should_receive(:puts) do |s|
          s[dumps[3].path.to_s].should_not be_nil
          s['Horrible error'].should_not be_nil
        end
        DumpRake.cleanup
      }
    end
  end
end
