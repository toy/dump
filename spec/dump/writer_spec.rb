require 'spec_helper'
require 'dump/writer'

Writer = Dump::Writer
describe Writer do
  describe 'create' do
    it 'creates instance and open' do
      @dump = double('dump')
      expect(@dump).to receive(:open)
      expect(Writer).to receive(:new).with('/abc/123.tmp').and_return(@dump)
      Writer.create('/abc/123.tmp')
    end

    it 'calls dump subroutines' do
      @dump = double('dump')
      allow(@dump).to receive(:open).and_yield(@dump)
      allow(@dump).to receive(:silence).and_yield
      allow(Writer).to receive(:new).and_return(@dump)

      expect(@dump).to receive(:write_schema).ordered
      expect(@dump).to receive(:write_tables).ordered
      expect(@dump).to receive(:write_assets).ordered
      expect(@dump).to receive(:write_config).ordered

      Writer.create('/abc/123.tmp')
    end
  end

  describe 'open' do
    it 'creates dir for dump' do
      allow(Zlib::GzipWriter).to receive(:open)
      expect(FileUtils).to receive(:mkpath).with('/abc/def/ghi')
      Writer.new('/abc/def/ghi/123.tgz').open
    end

    it 'sets stream to gzipped tar writer' do
      allow(FileUtils).to receive(:mkpath)
      @gzip = double('gzip')
      @stream = double('stream')
      expect(Zlib::GzipWriter).to receive(:open).with(Pathname('123.tgz')).and_yield(@gzip)
      expect(Archive::Tar::Minitar::Output).to receive(:open).with(@gzip).and_yield(@stream)
      expect(@gzip).to receive(:mtime=).with(Time.utc(2000))

      @dump = Writer.new('123.tgz')
      expect(@dump).to receive(:lock).and_yield
      @dump.open do |dump|
        expect(dump).to eq(@dump)
        expect(dump.stream).to eq(@stream)
      end
    end
  end

  describe 'subroutines' do
    before do
      @tar = double('tar')
      @stream = double('stream', :tar => @tar)
      @config = {:tables => {}}
      @dump = Writer.new('123.tgz')
      allow(@dump).to receive(:stream).and_return(@stream)
      allow(@dump).to receive(:config).and_return(@config)
      allow(Progress).to receive(:io).and_return(StringIO.new)
    end

    describe 'create_file' do
      it 'creates temp file, yields it for writing, creates file in tar and writes it there' do
        @temp = double('temp', :open => true, :length => 6, :read => 'qwfpgj')
        expect(@temp).to receive(:write).with('qwfpgj')
        allow(@temp).to receive(:eof?).and_return(false, true)
        expect(Tempfile).to receive(:open).and_yield(@temp)

        @file = double('file')
        expect(@file).to receive(:write).with('qwfpgj')

        expect(@stream.tar).to receive(:add_file_simple).with('abc/def.txt', :mode => 0100444, :size => 6).and_yield(@file)

        @dump.create_file('abc/def.txt') do |file|
          expect(file).to eq(@temp)
          file.write('qwfpgj')
        end
      end
    end

    describe 'write_schema' do
      it 'creates file schema.rb' do
        expect(@dump).to receive(:create_file).with('schema.rb')
        @dump.write_schema
      end

      it 'sets ENV[SCHEMA] to path of returned file' do
        @file = double('file', :path => 'db/schema.rb')
        allow(@dump).to receive(:create_file).and_yield(@file)
        expect(Dump::Env).to receive(:with_env).with('SCHEMA' => 'db/schema.rb')
        @dump.write_schema
      end

      it 'calls rake task db:schema:dump' do
        @file = double('file', :path => 'db/schema.rb')
        allow(@dump).to receive(:create_file).and_yield(@file)
        @task = double('task')
        expect(Rake::Task).to receive(:[]).with('db:schema:dump').and_return(@task)
        expect(@task).to receive(:invoke)
        @dump.write_schema
      end
    end

    describe 'write_tables' do
      it 'verifies connection' do
        allow(@dump).to receive(:tables_to_dump).and_return([])
        expect(@dump).to receive(:verify_connection)
        @dump.write_tables
      end

      it 'calls write_table for each table returned by tables_to_dump' do
        allow(@dump).to receive(:verify_connection)
        allow(@dump).to receive(:tables_to_dump).and_return(%w[first second])

        expect(@dump).to receive(:write_table).with('first')
        expect(@dump).to receive(:write_table).with('second')

        @dump.write_tables
      end
    end

    describe 'write_table' do
      it 'gets row count and store it to config' do
        expect(@dump).to receive(:table_row_count).with('first').and_return(666)
        allow(@dump).to receive(:create_file)
        @dump.write_table('first')
        expect(@config[:tables]['first']).to eq(666)
      end

      it 'create_files' do
        allow(@dump).to receive(:table_row_count).and_return(666)
        expect(@dump).to receive(:create_file)
        @dump.write_table('first')
      end

      it 'dumps column names and values of each row' do
        @column_definitions = [
          double('column', :name => 'id'),
          double('column', :name => 'name'),
          double('column', :name => 'associated_id'),
        ]
        allow(ActiveRecord::Base.connection).to receive(:columns).and_return(@column_definitions)
        @rows = [
          {'id' => 1, 'name' => 'a', 'associated_id' => 100},
          {'id' => 2, 'name' => 'b', 'associated_id' => 666},
        ]

        @file = double('file')
        allow(@dump).to receive(:table_row_count).and_return(666)
        allow(@dump).to receive(:create_file).and_yield(@file)

        column_names = @column_definitions.map(&:name).sort
        expect(Marshal).to receive(:dump).with(column_names, @file).ordered
        each_tabler_row_yielder = expect(@dump).to receive(:each_table_row)
        @rows.each do |row|
          each_tabler_row_yielder.and_yield(row)
          expect(Marshal).to receive(:dump).with(row.values_at(*column_names), @file).ordered
          @column_definitions.each do |column_definition|
            expect(column_definition).to receive(:type_cast).with(row[column_definition.name]).and_return(row[column_definition.name])
          end
        end

        @dump.write_table('first')
      end
    end

    describe 'write_assets' do
      before do
        allow(@dump).to receive(:assets_root_link).and_yield('/tmp', 'assets')
      end

      it 'calls assets_to_dump' do
        expect(@dump).to receive(:assets_to_dump).and_return([])
        @dump.write_assets
      end

      it 'changes root to rails app root' do
        @file = double('file')
        allow(@dump).to receive(:assets_to_dump).and_return(%w[images videos])
        allow(@dump).to receive(:create_file).and_yield(@file)

        expect(Dir).to receive(:chdir).with(Dump.rails_root)
        @dump.write_assets
      end

      it 'puts assets to config' do
        @file = double('file')
        allow(@dump).to receive(:assets_to_dump).and_return(%w[images/* videos])
        allow(@dump).to receive(:create_file).and_yield(@file)
        allow(Dir).to receive(:chdir).and_yield
        @tar = double('tar_writer')
        allow(Archive::Tar::Minitar::Output).to receive(:open).and_yield(@tar)
        allow(Dir).to receive(:[]).and_return([])
        expect(Dir).to receive(:[]).with(*%w[images/* videos]).and_return(%w[images/a images/b videos])

        @dump.write_assets
        counts = {:files => 0, :total => 0}
        expect(@config[:assets]).to eq({'images/a' => counts, 'images/b' => counts, 'videos' => counts})
      end

      it 'uses glob to find files' do
        @file = double('file')
        allow(@dump).to receive(:assets_to_dump).and_return(%w[images/* videos])
        allow(@dump).to receive(:create_file).and_yield(@file)
        allow(Dir).to receive(:chdir).and_yield
        @tar = double('tar_writer')
        allow(Archive::Tar::Minitar::Output).to receive(:open).and_yield(@tar)

        expect(Dir).to receive(:[]).with(*%w[images/* videos]).and_return(%w[images/a images/b videos])
        expect(Dir).to receive(:[]).with('images/a/**/*').and_return([])
        expect(Dir).to receive(:[]).with('images/b/**/*').and_return([])
        expect(Dir).to receive(:[]).with('videos/**/*').and_return([])

        @dump.write_assets
      end

      it 'packs each file from assets_root_link' do
        @file = double('file')
        allow(@dump).to receive(:assets_to_dump).and_return(%w[images/* videos])
        allow(@dump).to receive(:create_file).and_yield(@file)
        allow(Dir).to receive(:chdir).and_yield
        @tar = double('tar_writer')
        allow(Archive::Tar::Minitar::Output).to receive(:open).and_yield(@tar)

        expect(Dir).to receive(:[]).with(*%w[images/* videos]).and_return(%w[images/a images/b videos])
        expect(Dir).to receive(:[]).with('images/a/**/*').and_return([])
        expect(Dir).to receive(:[]).with('images/b/**/*').and_return([])
        expect(Dir).to receive(:[]).with('videos/**/*').and_return([])

        expect(@dump).to receive(:assets_root_link).exactly(3).times

        @dump.write_assets
      end

      it 'packs each file' do
        @file = double('file')
        allow(@dump).to receive(:assets_to_dump).and_return(%w[images/* videos])
        allow(@dump).to receive(:create_file).and_yield(@file)
        allow(Dir).to receive(:chdir).and_yield
        @tar = double('tar_writer')
        allow(Archive::Tar::Minitar::Output).to receive(:open).and_yield(@tar)

        expect(Dir).to receive(:[]).with(*%w[images/* videos]).and_return(%w[images/a images/b videos])
        expect(Dir).to receive(:[]).with('images/a/**/*').and_return(%w[a.jpg b.jpg])
        expect(Dir).to receive(:[]).with('images/b/**/*').and_return(%w[c.jpg d.jpg])
        expect(Dir).to receive(:[]).with('videos/**/*').and_return(%w[a.mov b.mov])

        %w[a.jpg b.jpg c.jpg d.jpg a.mov b.mov].each do |file_name|
          expect(Archive::Tar::Minitar).to receive(:pack_file).with("assets/#{file_name}", @stream)
        end

        @dump.write_assets
      end

      it 'does not raise if something fails when packing' do
        @file = double('file')
        allow(@dump).to receive(:assets_to_dump).and_return(%w[videos])
        allow(@dump).to receive(:create_file).and_yield(@file)
        allow(Dir).to receive(:chdir).and_yield
        @tar = double('tar_writer')
        allow(Archive::Tar::Minitar::Output).to receive(:open).and_yield(@tar)

        expect(Dir).to receive(:[]).with(*%w[videos]).and_return(%w[videos])
        expect(Dir).to receive(:[]).with('videos/**/*').and_return(%w[a.mov b.mov])

        expect(Archive::Tar::Minitar).to receive(:pack_file).with('assets/a.mov', @stream).and_raise('file not found')
        expect(Archive::Tar::Minitar).to receive(:pack_file).with('assets/b.mov', @stream)

        grab_output do
          @dump.write_assets
        end
      end

    end

    describe 'write_config' do
      it 'creates file config' do
        expect(@dump).to receive(:create_file).with('config')
        @dump.write_config
      end

      it 'dumps column names and values of each row' do
        @file = double('file')
        allow(@dump).to receive(:create_file).and_yield(@file)
        @config.replace({:tables => {'first' => 1, 'second' => 2}, :assets => %w[images videos]})

        expect(Marshal).to receive(:dump).with(@config, @file)
        @dump.write_config
      end
    end

    describe 'assets_to_dump' do
      it 'calls rake task assets' do
        @task = double('task')
        expect(Rake::Task).to receive(:[]).with('assets').and_return(@task)
        expect(@task).to receive(:invoke)
        @dump.assets_to_dump
      end

      it 'returns array of assets if separator is colon' do
        @task = double('task')
        allow(Rake::Task).to receive(:[]).and_return(@task)
        allow(@task).to receive(:invoke)
        Dump::Env.with_env(:assets => 'images:videos') do
          expect(@dump.assets_to_dump).to eq(%w[images videos])
        end
      end

      it 'returns array of assets if separator is comma' do
        @task = double('task')
        allow(Rake::Task).to receive(:[]).and_return(@task)
        allow(@task).to receive(:invoke)
        Dump::Env.with_env(:assets => 'images,videos') do
          expect(@dump.assets_to_dump).to eq(%w[images videos])
        end
      end

      it 'returns empty array if calling rake task assets raises an exception' do
        allow(Rake::Task).to receive(:[]).and_raise('task assets not found')
        Dump::Env.with_env(:assets => 'images:videos') do
          expect(@dump.assets_to_dump).to eq([])
        end
      end
    end
  end
end
