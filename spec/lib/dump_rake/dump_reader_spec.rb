require File.dirname(__FILE__) + '/../../spec_helper'

require File.dirname(__FILE__) + '/../../../lib/dump_rake'
require File.dirname(__FILE__) + '/../../../lib/dump_rake/dump_reader'

def object_of_length(required_length)
  LengthConstraint.new(required_length)
end

class LengthConstraint
  def initialize(required_length)
    @required_length = required_length
  end

  def ==(value)
    @required_length == value.length
  end
end

DumpReader = DumpRake::DumpReader
describe DumpReader do
  describe "restore" do
    it "should create selves instance and open" do
      @dump = mock('dump')
      @dump.should_receive(:open)
      DumpReader.should_receive(:new).with('/abc/123.tmp').and_return(@dump)
      DumpReader.restore('/abc/123.tmp')
    end

    it "should call dump subroutines" do
      @dump = mock('dump')
      @dump.stub!(:open).and_yield(@dump)
      DumpReader.stub!(:new).and_return(@dump)

      @dump.should_receive(:read_config).ordered
      @dump.should_receive(:read_schema).ordered
      @dump.should_receive(:read_tables).ordered
      @dump.should_receive(:read_assets).ordered

      DumpReader.restore('/abc/123.tmp')
    end
  end

  describe "summary" do
    Summary = DumpReader::Summary
    describe Summary do
      it "should format text" do
        @summary = Summary.new
        @summary.header 'One'
        @summary.data(%w(fff ggg jjj ppp qqq www))
        @summary.header 'Two'
        @summary.data([['fff', 234], ['ggg', 321], ['jjj', 666], ['ppp', 678], ['qqq', 123], ['www', 345]].map{ |entry| entry.join(': ') })

        output = <<-TEXT
          One:
            fff
            ggg
            jjj
            ppp
            qqq
            www
          Two:
            fff: 234
            ggg: 321
            jjj: 666
            ppp: 678
            qqq: 123
            www: 345
        TEXT
        "#{@summary}".should == output.gsub(/#{output[/^\s+/]}/, '  ')
      end

      it "should pluralize" do
        Summary.pluralize(0, 'file').should == '0 files'
        Summary.pluralize(1, 'file').should == '1 file'
        Summary.pluralize(10, 'file').should == '10 files'
      end
    end

    it "should create selves instance and open" do
      @dump = mock('dump')
      @dump.should_receive(:open)
      DumpReader.should_receive(:new).with('/abc/123.tmp').and_return(@dump)
      DumpReader.summary('/abc/123.tmp')
    end

    {
      {'path/a' => {:total => 20, :files => 10}, 'path/b' => {:total => 20, :files => 10}} => ['path/a: 10 files (20 entries total)', 'path/b: 10 files (20 entries total)'],
      {'path/a' => 10, 'path/b' => 20} => ['path/a: 10 entries', 'path/b: 20 entries'],
      %w(path/a path/b) => %w(path/a path/b),
    }.each do |assets, formatted_assets|
      it "should call dump subroutines and create summary" do
        tables = {'a' => 10, 'b' => 20, 'c' => 666}
        formatted_tables = ['a: 10 rows', 'b: 20 rows', 'c: 666 rows']

        @dump = mock('dump')
        @dump.stub!(:config).and_return(:tables => tables, :assets => assets)
        @dump.stub!(:open).and_yield(@dump)
        DumpReader.stub!(:new).and_return(@dump)
        @dump.should_receive(:read_config)

        @summary = mock('summary')
        @summary.should_receive(:header).with('Tables')
        @summary.should_receive(:data).with(formatted_tables)
        @summary.should_receive(:header).with('Assets')
        @summary.should_receive(:data).with(formatted_assets)
        Summary.stub!(:new).and_return(@summary)

        DumpReader.summary('/abc/123.tmp').should == @summary
      end
    end

    it "should call dump subroutines and create summary with schema" do
      tables = {'a' => 10, 'b' => 20, 'c' => 666}
      formatted_tables = ['a: 10 rows', 'b: 20 rows', 'c: 666 rows']
      assets = formatted_assets = %w(path/a path/b)

      schema = mock('schema')
      schema_lines = mock('schema_lines')
      schema.should_receive(:split).with("\n").and_return(schema_lines)

      @dump = mock('dump')
      @dump.stub!(:config).and_return(:tables => tables, :assets => assets)
      @dump.stub!(:open).and_yield(@dump)
      @dump.stub!(:schema).and_return(schema)
      DumpReader.stub!(:new).and_return(@dump)
      @dump.should_receive(:read_config)

      @summary = mock('summary')
      @summary.should_receive(:header).with('Tables')
      @summary.should_receive(:data).with(formatted_tables)
      @summary.should_receive(:header).with('Assets')
      @summary.should_receive(:data).with(formatted_assets)
      @summary.should_receive(:header).with('Schema')
      @summary.should_receive(:data).with(schema_lines)
      Summary.stub!(:new).and_return(@summary)

      DumpReader.summary('/abc/123.tmp', :schema => true).should == @summary
    end
  end

  describe "open" do
    it "should set stream to gzipped tar reader" do
      @gzip = mock('gzip')
      @stream = mock('stream')
      Zlib::GzipReader.should_receive(:open).with(Pathname("123.tgz")).and_yield(@gzip)
      Archive::Tar::Minitar::Input.should_receive(:open).with(@gzip).and_yield(@stream)

      @dump = DumpReader.new('123.tgz')
      @dump.open do |dump|
        dump.should == @dump
        dump.stream.should == @stream
      end
    end
  end

  describe "low level" do
    before do
      @e1 = mock('e1', :full_name => 'config', :read => 'config_data')
      @e2 = mock('e2', :full_name => 'first.dump', :read => 'first.dump_data')
      @e3 = mock('e3', :full_name => 'second.dump', :read => 'second.dump_data')
      @stream = [@e1, @e2, @e3]
      @dump = DumpReader.new('123.tgz')
      @dump.stub!(:stream).and_return(@stream)
    end

    describe "find_entry" do
      it "should find first entry in stream equal string" do
        @dump.find_entry('config') do |entry|
          entry.should == @e1
        end
      end

      it "should find first entry in stream matching regexp" do
        @dump.find_entry(/\.dump$/) do |entry|
          entry.should == @e2
        end
      end

      it "should return result of block" do
        @dump.find_entry(/\.dump$/) do |entry|
          'hello'
        end.should == 'hello'
      end
    end

    describe "read_entry" do
      it "should call find_entry" do
        @dump.should_receive(:find_entry).with('config').and_yield(@e1)
        @dump.read_entry('config')
      end

      it "should read entries data" do
        @dump.read_entry('config').should == 'config_data'
      end
    end

    describe "read_entry_to_file" do
      it "should call find_entry" do
        @dump.should_receive(:find_entry).with('config')
        @dump.read_entry_to_file('config')
      end

      it "should open temp file, write data there, rewind and yield that file" do
        @entry = mock('entry')
        @dump.stub!(:find_entry).and_yield(@entry)
        @temp = mock('temp')
        Tempfile.should_receive(:open).and_yield(@temp)

        @entry.should_receive(:eof?).and_return(false, false, true)
        @entry.should_receive(:read).with(4096).and_return('a' * 4096, 'b' * 1000)
        @temp.should_receive(:write).with('a' * 4096).ordered
        @temp.should_receive(:write).with('b' * 1000).ordered
        @temp.should_receive(:rewind).ordered

        @dump.read_entry_to_file('config') do |f|
          f.should == @temp
        end
      end
    end
  end

  describe "subroutines" do
    before do
      @stream = mock('stream')
      @dump = DumpReader.new('123.tgz')
      @dump.stub!(:stream).and_return(@stream)
      Progress.io = StringIO.new
    end

    describe "read_config" do
      it "should read config" do
        @data = {:tables => {:first => 1}, :assets => %w(images videos)}
        @dump.should_receive(:read_entry).with('config').and_return(Marshal.dump(@data))

        @dump.read_config
        @dump.config.should == @data
      end
    end

    describe "read_schema" do
      before do
        @task = mock('task')
        Rake::Task.stub!(:[]).and_return(@task)
        @task.stub!(:invoke)
      end

      it "should read schema.rb to temp file" do
        @dump.should_receive(:read_entry_to_file).with('schema.rb')
        @dump.read_schema
      end

      it "should set ENV SCHEMA to temp files path" do
        @file = mock('tempfile', :path => '/temp/123-arst')
        @dump.stub!(:read_entry_to_file).and_yield(@file)

        DumpRake::Env.should_receive(:with_env).with('SCHEMA' => '/temp/123-arst')
        @dump.read_schema
      end

      it "should call task db:schema:load and db:schema:dump" do
        @file = mock('tempfile', :path => '/temp/123-arst')
        @dump.stub!(:read_entry_to_file).and_yield(@file)

        @load_task = mock('load_task')
        @dump_task = mock('dump_task')
        Rake::Task.should_receive(:[]).with('db:schema:load').and_return(@load_task)
        Rake::Task.should_receive(:[]).with('db:schema:dump').and_return(@dump_task)
        @load_task.should_receive(:invoke)
        @dump_task.should_receive(:invoke)

        @dump.read_schema
      end
    end

    describe "schema" do
      it "should read schema" do
        @data = %q{create table, rows, etc...}
        @dump.should_receive(:read_entry).with('schema.rb').and_return(@data)
        @dump.schema.should == @data
      end
    end

    describe "read_tables" do
      it "should verify connection" do
        @dump.stub!(:config).and_return({:tables => []})
        @dump.should_receive(:verify_connection)
        @dump.read_tables
      end

      it "should call read_table for each table in config" do
        @dump.stub!(:verify_connection)
        @dump.stub!(:config).and_return({:tables => {'first' => 1, 'second' => 3}})

        @dump.should_receive(:read_table).with('first', 1)
        @dump.should_receive(:read_table).with('second', 3)

        @dump.read_tables
      end
    end

    describe "read_table" do
      it "should not read table if no entry found for table" do
        @dump.should_receive(:find_entry).with('first.dump').and_return(nil)
        @dump.should_not_receive(:quote_table_name)
        @dump.read_table('first', 10)
      end

      it "should read table if entry found for table" do
        @entry = mock('entry', :to_str => Marshal.dump('data'), :eof? => true)
        @dump.should_receive(:find_entry).with('first.dump').and_yield(@entry)
        @dump.should_receive(:quote_table_name).with('first')
        @dump.read_table('first', 10)
      end

      it "should not call clear_table for basic tables" do
        @entry = mock('entry', :to_str => Marshal.dump('data'), :eof? => true)
        @dump.should_receive(:find_entry).with('first.dump').and_yield(@entry)
        @dump.should_receive(:quote_table_name).with('first')
        @dump.should_not_receive(:clear_table)
        @dump.read_table('first', 10)
      end

      it "should clear schema table before writing" do
        @entry = mock('entry', :to_str => Marshal.dump('data'), :eof? => true)
        @dump.should_receive(:find_entry).with('schema_migrations.dump').and_yield(@entry)
        @dump.should_receive(:quote_table_name).with('schema_migrations').and_return('`schema_migrations`')
        @dump.should_receive(:clear_table).with('`schema_migrations`')
        @dump.read_table('schema_migrations', 10)
      end

      describe "reading/writing data" do
        def create_entry(rows_count)
          @entry = StringIO.new

          @columns = %w(id name)
          @rows = []
          Marshal.dump(@columns, @entry)
          (1..rows_count).each do |i|
            row = [i, "entry#{i}"]
            @rows << row
            Marshal.dump(row, @entry)
          end
          @entry.rewind

          @dump.stub!(:find_entry).and_yield(@entry)
        end
        it "should read to eof" do
          create_entry(2500)
          @dump.stub!(:insert_into_table)
          @dump.read_table('first', 2500)
          @entry.eof?.should be_true
        end

        it "should try to insert rows in slices of 1000 rows" do
          create_entry(2500)
          @dump.should_receive(:insert_into_table).with(anything, anything, object_of_length(1000)).twice
          @dump.should_receive(:insert_into_table).with(anything, anything, object_of_length(500)).once

          @dump.read_table('first', 2500)
        end

        it "should try to insert row by row if slice method fails" do
          create_entry(2500)
          @dump.should_receive(:insert_into_table).with(anything, anything, kind_of(Array)).exactly(3).times.and_raise('sql error')
          @dump.should_receive(:insert_into_table).with(anything, anything, kind_of(String)).exactly(2500).times
          @dump.read_table('first', 2500)
        end

        it "should quote table, columns and values and send them to insert_into_table" do
          create_entry(100)
          @dump.should_receive(:quote_table_name).with('first').and_return('`first`')
          @dump.should_receive(:columns_insert_sql).with(@columns).and_return('(`id`, `name`)')
          @rows.each do |row|
            @dump.should_receive(:values_insert_sql).with(row).and_return{ |vs| vs.inspect }
          end

          @dump.should_receive(:insert_into_table).with('`first`', '(`id`, `name`)', @rows.map(&:inspect))
          @dump.read_table('first', 100)
        end
      end
    end

    describe "read_assets" do
      before do
        @task = mock('task')
        Rake::Task.stub!(:[]).with('assets:delete').and_return(@task)
        @task.stub!(:invoke)
      end

      it "should not read assets if config[:assets] is nil" do
        @dump.stub!(:config).and_return({})
        @dump.should_not_receive(:find_entry)
        @dump.read_assets
      end

      it "should not read assets if config[:assets] is blank" do
        @dump.stub!(:config).and_return({:assets => []})
        @dump.should_not_receive(:find_entry)
        @dump.read_assets
      end

      describe "deleting existing assets" do
        it "should call assets:delete" do
          @assets = %w(images videos)
          @dump.stub!(:config).and_return({:assets => @assets})
          @dump.stub!(:find_entry)

          @task.should_receive(:invoke)

          @dump.read_assets
        end

        it "should call assets:delete with ASSETS set to config[:assets] joined with :" do
          @assets = %w(images videos)
          @dump.stub!(:config).and_return({:assets => @assets})
          @dump.stub!(:find_entry)

          def @task.invoke
            DumpRake::Env[:assets].should == 'images:videos'
          end

          @dump.read_assets
        end
      end

      it "should find assets.tar" do
        @assets = %w(images videos)
        @dump.stub!(:config).and_return({:assets => @assets})
        Dir.stub!(:glob).and_return([])
        FileUtils.stub!(:remove_entry_secure)

        @dump.should_receive(:find_entry).with('assets.tar')
        @dump.read_assets
      end

      [
        %w(images videos),
        {'images' => 0, 'videos' => 0},
        {'images' => {:files => 0, :total => 0}, 'videos' => {:files => 0, :total => 0}},
      ].each do |assets|
        it "should rewrite rewind method to empty method - to not raise exception, open tar and extract each entry" do
          @dump.stub!(:config).and_return({:assets => assets})
          Dir.stub!(:glob).and_return([])
          FileUtils.stub!(:remove_entry_secure)

          @assets_tar = mock('assets_tar')
          @assets_tar.stub!(:rewind).and_raise('hehe - we want to rewind to center of gzip')
          @dump.stub!(:find_entry).and_yield(@assets_tar)

          @inp = mock('inp')
          each_excpectation = @inp.should_receive(:each)
          @entries = %w(a b c d).map do |s|
            file = mock("file_#{s}")
            each_excpectation.and_yield(file)
            @inp.should_receive(:extract_entry).with(RAILS_ROOT, file)
            file
          end
          Archive::Tar::Minitar.should_receive(:open).with(@assets_tar).and_yield(@inp)

          @dump.read_assets
        end
      end
    end

    describe "clear_table" do
      it "should call ActiveRecord::Base.connection.delete with sql for deleting everything from table" do
        ActiveRecord::Base.connection.should_receive(:delete).with('DELETE FROM `first`', anything)
        DumpReader.new('').send(:clear_table, '`first`')
      end
    end

    describe "quote_column_name" do
      it "should return result of ActiveRecord::Base.connection.quote_column_name" do
        ActiveRecord::Base.connection.should_receive(:quote_column_name).with('first').and_return('`first`')
        DumpReader.new('').send(:quote_column_name, 'first').should == '`first`'
      end
    end

    describe "quote_value" do
      it "should return result of ActiveRecord::Base.connection.quote_value" do
        ActiveRecord::Base.connection.should_receive(:quote).with('first').and_return('`first`')
        DumpReader.new('').send(:quote_value, 'first').should == '`first`'
      end
    end

    describe "join_for_sql" do
      it "should convert array ['`a`', '`b`'] to \"(`a`,`b`)\"" do
        DumpReader.new('').send(:join_for_sql, %w(`a` `b`)).should == '(`a`,`b`)'
      end
    end

    describe "insert_into_table" do
      it "should call ActiveRecord::Base.connection.insert with sql for insert if values is string" do
        ActiveRecord::Base.connection.should_receive(:insert).with("INSERT INTO `table` (`c1`,`c2`) VALUES (`v1`,`v2`)", anything)
        DumpReader.new('').send(:insert_into_table, '`table`', '(`c1`,`c2`)', '(`v1`,`v2`)')
      end

      it "should call ActiveRecord::Base.connection.insert with sql for insert if values is array" do
        ActiveRecord::Base.connection.should_receive(:insert).with("INSERT INTO `table` (`c1`,`c2`) VALUES (`v11`,`v12`),(`v21`,`v22`)", anything)
        DumpReader.new('').send(:insert_into_table, '`table`', '(`c1`,`c2`)', ['(`v11`,`v12`)', '(`v21`,`v22`)'])
      end
    end

    describe "columns_insert_sql" do
      it "should return columns sql part for insert" do
        @dump = DumpReader.new('')
        @dump.should_receive(:quote_column_name).with('a').and_return('`a`')
        @dump.should_receive(:quote_column_name).with('b').and_return('`b`')

        @dump.send(:columns_insert_sql, %w(a b)).should == '(`a`,`b`)'
      end
    end

    describe "values_insert_sql" do
      it "should return values sql part for insert" do
        @dump = DumpReader.new('')
        @dump.should_receive(:quote_value).with('a').and_return('`a`')
        @dump.should_receive(:quote_value).with('b').and_return('`b`')

        @dump.send(:values_insert_sql, %w(a b)).should == '(`a`,`b`)'
      end
    end
  end
end
