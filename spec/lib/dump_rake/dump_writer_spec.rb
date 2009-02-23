require File.dirname(__FILE__) + '/../../spec_helper'

DumpWriter = DumpRake::DumpWriter
describe DumpWriter do
  describe "create" do
    it "should create selves instance and open" do
      @dump = mock('dump')
      @dump.should_receive(:open)
      DumpWriter.should_receive(:new).with('/abc/123.tmp').and_return(@dump)
      DumpWriter.create('/abc/123.tmp')
    end

    it "should call dump subroutines" do
      @dump = mock('dump')
      @dump.stub!(:open).and_yield(@dump)
      DumpWriter.stub!(:new).and_return(@dump)

      @dump.should_receive(:write_schema)
      @dump.should_receive(:write_tables)
      @dump.should_receive(:write_assets)
      @dump.should_receive(:write_config)

      DumpWriter.create('/abc/123.tmp')
    end
  end

  describe "open" do
    it "should create dir for dump" do
      Zlib::GzipWriter.stub!(:open)
      FileUtils.should_receive(:mkpath).with('/abc/def/ghi')
      DumpWriter.new('/abc/def/ghi/123.tgz').open
    end

    it "should set stream to gzipped tar and call dump subroutines" do
      FileUtils.stub!(:mkpath)
      @gzip = mock('gzip')
      @stream = mock('stream')
      Zlib::GzipWriter.should_receive(:open).with("123.tgz").and_yield(@gzip)
      Archive::Tar::Minitar::Output.should_receive(:open).with(@gzip).and_yield(@stream)

      @dump = DumpWriter.new('123.tgz')
      @dump.open do |dump|
        dump.should == @dump
        dump.stream.should == @stream
      end
    end
  end

  describe "create_file" do
    it "should create temp file, yield it for writing, create file in tar and write it there" do
      @temp = mock('temp', :open => true, :length => 6, :read => 'qwfpgj')
      @temp.should_receive(:write).with('qwfpgj')
      @temp.stub!(:eof?).and_return(false, true)
      Tempfile.should_receive(:open).and_yield(@temp)

      @file = mock('file')
      @file.should_receive(:write).with('qwfpgj')

      @tar = mock('tar')
      @stream = mock('stream', :tar => @tar)
      @stream.tar.should_receive(:add_file_simple).with('abc/def.txt', :mode => 0100444, :size => 6).and_yield(@file)

      @dump = DumpWriter.new('123.tgz')
      @dump.stub!(:stream).and_return(@stream)
      @dump.create_file('abc/def.txt') do |file|
        file.should == @temp
        file.write('qwfpgj')
      end
    end
  end

  describe "subroutines" do
    before do
      @tar = mock('tar')
      @stream = mock('stream', :tar => @tar)
      @config = {:tables => {}}
      @dump = DumpWriter.new('123.tgz')
      @dump.stub!(:stream).and_return(@stream)
      @dump.stub!(:config).and_return(@config)
      Progress.io = StringIO.new
    end

    describe "write_schema" do
      it "should create file schema.rb" do
        @dump.should_receive(:create_file).with('schema.rb')
        @dump.write_schema
      end

      it "should set ENV[SCHEMA] to path of returned file" do
        @file = mock('file', :path => 'db/schema.rb')
        @dump.stub!(:create_file).and_yield(@file)
        @dump.should_receive(:with_env).with('SCHEMA', 'db/schema.rb')
        @dump.write_schema
      end

      it "should call rake task db:schema:dump" do
        @file = mock('file', :path => 'db/schema.rb')
        @dump.stub!(:create_file).and_yield(@file)
        @task = mock('task')
        Rake::Task.should_receive(:[]).with('db:schema:dump').and_return(@task)
        @task.should_receive(:invoke)
        @dump.write_schema
      end
    end

    describe "write_tables" do
      it "should establish connection" do
        @dump.stub!(:tables_to_dump).and_return([])
        @dump.should_receive(:establish_connection)
        @dump.write_tables
      end

      it "should call write_table for each table returned by tables_to_dump" do
        @dump.stub!(:establish_connection)
        @dump.stub!(:tables_to_dump).and_return(%w(first second))

        @dump.should_receive(:write_table).with('first')
        @dump.should_receive(:write_table).with('second')

        @dump.write_tables
      end
    end

    describe "write_table" do
      before do
        @rows = [
          {'id' => 1, 'name' => 'a', 'associated_id' => 100},
          {'id' => 2, 'name' => 'b', 'associated_id' => 666},
        ]
      end

      it "should call table_rows" do
        @dump.should_receive(:table_rows).with('first').and_return([])
        @dump.write_table('first')
      end

      it "should not create_file if rows are empty" do
        @dump.stub!(:table_rows).and_return([])
        @dump.should_not_receive(:create_file)
        @dump.write_table('first')
      end

      it "should create_file if rows are not empty" do
        @dump.stub!(:table_rows).and_return(@rows)
        @dump.should_receive(:create_file).with('first.dump')
        @dump.write_table('first')
      end

      it "should add table => rows.length to config" do
        @dump.stub!(:table_rows).and_return(@rows)
        @dump.stub!(:create_file)
        @dump.write_table('first')
        @config[:tables]['first'].should == 2
      end

      it "should dump column names and values of each row" do
        @file = mock('file')
        @dump.stub!(:table_rows).and_return(@rows)
        @dump.stub!(:create_file).and_yield(@file)

        @columns = @rows.first.keys.sort
        @file.should_receive(:write).with(Marshal.dump(@columns)).ordered
        @rows.each do |row|
          @file.should_receive(:write).with(Marshal.dump(row.values_at(*@columns))).ordered
        end

        @dump.write_table('first')
      end
    end

    describe "write_assets" do
      it "should call assets_to_dump" do
        @dump.should_receive(:assets_to_dump).and_return([])
        @dump.write_assets
      end

      it "should not create_file if assets are empty" do
        @dump.stub!(:assets_to_dump).and_return([])

        @dump.should_not_receive(:create_file)
        @dump.write_assets
      end

      it "should create_file assets.tar if assets are not empty" do
        @dump.stub!(:assets_to_dump).and_return(%w(images videos))

        @dump.should_receive(:create_file).with('assets.tar')
        @dump.write_assets
      end

      it "should put assets to config" do
        @assets = %w(images videos)
        @dump.stub!(:assets_to_dump).and_return(@assets)
        @dump.stub!(:create_file)

        @dump.write_assets
        @config[:assets].should == @assets
      end

      it "should change root to RAILS_ROOT" do
        @file = mock('file')
        @dump.stub!(:assets_to_dump).and_return(%w(images videos))
        @dump.stub!(:create_file).and_yield(@file)

        Dir.should_receive(:chdir).with(RAILS_ROOT)
        @dump.write_assets
      end

      it "should pack each asset" do
        @file = mock('file')
        @dump.stub!(:assets_to_dump).and_return(%w(images videos))
        @dump.stub!(:create_file).and_yield(@file)
        Dir.stub!(:chdir).and_yield

        Archive::Tar::Minitar.should_receive(:pack).with('images', @file)
        Archive::Tar::Minitar.should_receive(:pack).with('videos', @file)
        @dump.write_assets
      end
    end

    describe "write_config" do
      it "should create file config" do
        @dump.should_receive(:create_file).with('config')
        @dump.write_config
      end

      it "should dump column names and values of each row" do
        @file = mock('file')
        @dump.stub!(:create_file).and_yield(@file)
        @config.replace({:tables => {'first' => 1, 'second' => 2}, :assets => %w(images videos)})

        @file.should_receive(:write).with(Marshal.dump(@config))
        @dump.write_config
      end
    end
    
    describe "tables_to_dump" do
      it "should call ActiveRecord::Base.connection.tables" do
        ActiveRecord::Base.connection.should_receive(:tables).and_return([])
        @dump.tables_to_dump
      end

      it "should exclude certain tables from result" do
        ActiveRecord::Base.connection.should_receive(:tables).and_return(%w(first second schema_info))
        @dump.tables_to_dump.should == %w(first second)
      end
    end

    describe "table_rows" do
      it "should call ActiveRecord::Base.connection.select_all with sql containing quoted table name" do
        @dump.should_receive(:quote_table_name).and_return('`first`')
        ActiveRecord::Base.connection.should_receive(:select_all).with("SELECT * FROM `first`")
        @dump.table_rows('first')
      end
    end

    describe "assets_to_dump" do
      it "should call rake task assets" do
        @task = mock('task')
        Rake::Task.should_receive(:[]).with('assets').and_return(@task)
        @task.should_receive(:invoke)
        @dump.assets_to_dump
      end

      it "should return array of assets" do
        @task = mock('task')
        Rake::Task.stub!(:[]).and_return(@task)
        @task.stub!(:invoke)
        with_env('ASSETS', 'images:videos') do
          @dump.assets_to_dump.should == %w(images videos)
        end
      end

      it "should return empty array if calling rake task assets raises an exception" do
        Rake::Task.stub!(:[]).and_raise('task assets not found')
        with_env('ASSETS', 'images:videos') do
          @dump.assets_to_dump.should == []
        end
      end
    end
  end
end
