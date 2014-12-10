require 'spec_helper'
require 'dump/reader'
require 'active_record/migration'

Reader = Dump::Reader
describe Reader do
  describe 'restore' do
    it 'creates instance and opens' do
      @dump = double('dump')
      expect(@dump).to receive(:open)
      expect(Reader).to receive(:new).with('/abc/123.tmp').and_return(@dump)
      Reader.restore('/abc/123.tmp')
    end

    it 'calls dump subroutines' do
      @dump = double('dump')
      allow(@dump).to receive(:open).and_yield(@dump)
      allow(@dump).to receive(:silence).and_yield
      allow(Reader).to receive(:new).and_return(@dump)

      expect(@dump).to receive(:read_config).ordered
      expect(@dump).to receive(:migrate_down).ordered
      expect(@dump).to receive(:read_schema).ordered
      expect(@dump).to receive(:read_tables).ordered
      expect(@dump).to receive(:read_assets).ordered

      Reader.restore('/abc/123.tmp')
    end
  end

  describe 'summary' do
    Summary = Reader::Summary
    describe Summary do
      it 'formats text' do
        @summary = Summary.new
        @summary.header 'One'
        @summary.data(%w[fff ggg jjj ppp qqq www])
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
        expect("#{@summary}").to eq(output.gsub(/#{output[/^\s+/]}/, '  '))
      end

      it 'pluralizes' do
        expect(Summary.pluralize(0, 'file')).to eq('0 files')
        expect(Summary.pluralize(1, 'file')).to eq('1 file')
        expect(Summary.pluralize(10, 'file')).to eq('10 files')
      end
    end

    it 'creates instance and opens' do
      @dump = double('dump')
      expect(@dump).to receive(:open)
      expect(Reader).to receive(:new).with('/abc/123.tmp').and_return(@dump)
      Reader.summary('/abc/123.tmp')
    end

    {
      {'path/a' => {:total => 20, :files => 10}, 'path/b' => {:total => 20, :files => 10}} => ['path/a: 10 files (20 entries total)', 'path/b: 10 files (20 entries total)'],
      {'path/a' => 10, 'path/b' => 20} => ['path/a: 10 entries', 'path/b: 20 entries'],
      %w[path/a path/b] => %w[path/a path/b],
    }.each do |assets, formatted_assets|
      it 'calls dump subroutines and creates summary' do
        tables = {'a' => 10, 'b' => 20, 'c' => 666}
        formatted_tables = ['a: 10 rows', 'b: 20 rows', 'c: 666 rows']

        @dump = double('dump')
        allow(@dump).to receive(:config).and_return(:tables => tables, :assets => assets)
        allow(@dump).to receive(:open).and_yield(@dump)
        allow(Reader).to receive(:new).and_return(@dump)
        expect(@dump).to receive(:read_config)

        @summary = double('summary')
        expect(@summary).to receive(:header).with('Tables')
        expect(@summary).to receive(:data).with(formatted_tables)
        expect(@summary).to receive(:header).with('Assets')
        expect(@summary).to receive(:data).with(formatted_assets)
        allow(Summary).to receive(:new).and_return(@summary)

        expect(Reader.summary('/abc/123.tmp')).to eq(@summary)
      end
    end

    it 'calls dump subroutines and creates summary with schema' do
      tables = {'a' => 10, 'b' => 20, 'c' => 666}
      formatted_tables = ['a: 10 rows', 'b: 20 rows', 'c: 666 rows']
      assets = formatted_assets = %w[path/a path/b]

      schema = double('schema')
      schema_lines = double('schema_lines')
      expect(schema).to receive(:split).with("\n").and_return(schema_lines)

      @dump = double('dump')
      allow(@dump).to receive(:config).and_return(:tables => tables, :assets => assets)
      allow(@dump).to receive(:open).and_yield(@dump)
      allow(@dump).to receive(:schema).and_return(schema)
      allow(Reader).to receive(:new).and_return(@dump)
      expect(@dump).to receive(:read_config)

      @summary = double('summary')
      expect(@summary).to receive(:header).with('Tables')
      expect(@summary).to receive(:data).with(formatted_tables)
      expect(@summary).to receive(:header).with('Assets')
      expect(@summary).to receive(:data).with(formatted_assets)
      expect(@summary).to receive(:header).with('Schema')
      expect(@summary).to receive(:data).with(schema_lines)
      allow(Summary).to receive(:new).and_return(@summary)

      expect(Reader.summary('/abc/123.tmp', :schema => true)).to eq(@summary)
    end
  end

  describe 'open' do
    it 'sets stream to gzipped tar reader' do
      @gzip = double('gzip')
      @stream = double('stream')
      expect(Zlib::GzipReader).to receive(:open).with(Pathname('123.tgz')).and_yield(@gzip)
      expect(Archive::Tar::Minitar::Input).to receive(:open).with(@gzip).and_yield(@stream)

      @dump = Reader.new('123.tgz')
      @dump.open do |dump|
        expect(dump).to eq(@dump)
        expect(dump.stream).to eq(@stream)
      end
    end
  end

  describe 'low level' do
    before do
      @e1 = double('e1', :full_name => 'config', :read => 'config_data')
      @e2 = double('e2', :full_name => 'first.dump', :read => 'first.dump_data')
      @e3 = double('e3', :full_name => 'second.dump', :read => 'second.dump_data')
      @stream = [@e1, @e2, @e3]
      @dump = Reader.new('123.tgz')
      allow(@dump).to receive(:stream).and_return(@stream)
    end

    describe 'find_entry' do
      it 'finds first entry in stream equal string' do
        @dump.find_entry('config') do |entry|
          expect(entry).to eq(@e1)
        end
      end

      it 'finds first entry in stream matching regexp' do
        @dump.find_entry(/\.dump$/) do |entry|
          expect(entry).to eq(@e2)
        end
      end

      it 'returns result of block' do
        expect(@dump.find_entry(/\.dump$/) do |_entry|
          'hello'
        end).to eq('hello')
      end
    end

    describe 'read_entry' do
      it 'calls find_entry' do
        expect(@dump).to receive(:find_entry).with('config').and_yield(@e1)
        @dump.read_entry('config')
      end

      it 'reads entries data' do
        expect(@dump.read_entry('config')).to eq('config_data')
      end
    end

    describe 'read_entry_to_file' do
      it 'calls find_entry' do
        expect(@dump).to receive(:find_entry).with('config')
        @dump.read_entry_to_file('config')
      end

      it 'opens temp file, writes data there, rewinds and yields that file' do
        @entry = double('entry')
        allow(@dump).to receive(:find_entry).and_yield(@entry)
        @temp = double('temp')
        expect(Tempfile).to receive(:open).and_yield(@temp)

        expect(@entry).to receive(:eof?).and_return(false, false, true)
        expect(@entry).to receive(:read).with(4096).and_return('a' * 4096, 'b' * 1000)
        expect(@temp).to receive(:write).with('a' * 4096).ordered
        expect(@temp).to receive(:write).with('b' * 1000).ordered
        expect(@temp).to receive(:rewind).ordered

        @dump.read_entry_to_file('config') do |f|
          expect(f).to eq(@temp)
        end
      end
    end
  end

  describe 'subroutines' do
    before do
      @stream = double('stream')
      @dump = Reader.new('123.tgz')
      allow(@dump).to receive(:stream).and_return(@stream)
      allow(Progress).to receive(:io).and_return(StringIO.new)
    end

    describe 'read_config' do
      it 'reads config' do
        @data = {:tables => {:first => 1}, :assets => %w[images videos]}
        expect(@dump).to receive(:read_entry).with('config').and_return(Marshal.dump(@data))

        @dump.read_config
        expect(@dump.config).to eq(@data)
      end
    end

    describe 'migrate_down' do
      it 'does not invoke rake tasks or find_entry if migrate_down is 0, no or false' do
        expect(Rake::Task).not_to receive(:[])
        expect(@dump).not_to receive(:find_entry)

        Dump::Env.with_env(:migrate_down => '0') do
          @dump.migrate_down
        end
        Dump::Env.with_env(:migrate_down => 'no') do
          @dump.migrate_down
        end
        Dump::Env.with_env(:migrate_down => 'false') do
          @dump.migrate_down
        end
      end

      it 'invokes db:drop and db:create if migrate_down is reset' do
        @load_task = double('drop_task')
        @dump_task = double('create_task')
        expect(Rake::Task).to receive(:[]).with('db:drop').and_return(@load_task)
        expect(Rake::Task).to receive(:[]).with('db:create').and_return(@dump_task)
        expect(@load_task).to receive(:invoke)
        expect(@dump_task).to receive(:invoke)

        Dump::Env.with_env(:migrate_down => 'reset') do
          @dump.migrate_down
        end
      end

      [nil, '1'].each do |migrate_down_value|
        describe "when migrate_down is #{migrate_down_value.inspect}" do
          it 'does not find_entry if table schema_migrations is not present' do
            allow(@dump).to receive(:avaliable_tables).and_return(%w[first])
            expect(@dump).not_to receive(:find_entry)

            Dump::Env.with_env(:migrate_down => migrate_down_value) do
              @dump.migrate_down
            end
          end

          it 'finds schema_migrations.dump if table schema_migrations is present' do
            allow(@dump).to receive(:avaliable_tables).and_return(%w[schema_migrations first])
            expect(@dump).to receive(:find_entry).with('schema_migrations.dump')

            Dump::Env.with_env(:migrate_down => migrate_down_value) do
              @dump.migrate_down
            end
          end

          it 'calls migrate down for each version not present in schema_migrations table' do
            @entry = StringIO.new
            Marshal.dump(['version'], @entry)
            %w[1 2 3 4].each do |i|
              Marshal.dump(i, @entry)
            end
            @entry.rewind

            allow(@dump).to receive(:avaliable_tables).and_return(%w[schema_migrations first])
            expect(@dump).to receive(:find_entry).with('schema_migrations.dump').and_yield(@entry)
            expect(@dump).to receive('table_rows').with('schema_migrations').and_return(%w[1 2 4 5 6 7].map{ |version| {'version' => version} })

            @versions = []
            @migrate_down_task = double('migrate_down_task')
            expect(@migrate_down_task).to receive('invoke').exactly(3).times do
              version = Dump::Env['VERSION']
              @versions << version
              if version == '6'
                fail ActiveRecord::IrreversibleMigration
              end
            end
            expect(@migrate_down_task).to receive('reenable').exactly(3).times

            expect($stderr).to receive('puts').with('Irreversible migration: 6')

            expect(Rake::Task).to receive(:[]).with('db:migrate:down').exactly(3).times.and_return(@migrate_down_task)

            Dump::Env.with_env(:migrate_down => migrate_down_value) do
              @dump.migrate_down
            end
            expect(@versions).to eq(%w[5 6 7].reverse)
          end
        end
      end
    end

    describe 'read_schema' do
      before do
        @task = double('task')
        allow(Rake::Task).to receive(:[]).and_return(@task)
        allow(@task).to receive(:invoke)
      end

      it 'reads schema.rb to temp file' do
        expect(@dump).to receive(:read_entry_to_file).with('schema.rb')
        @dump.read_schema
      end

      it 'sets ENV SCHEMA to temp files path' do
        @file = double('tempfile', :path => '/temp/123-arst')
        allow(@dump).to receive(:read_entry_to_file).and_yield(@file)

        expect(Dump::Env).to receive(:with_env).with('SCHEMA' => '/temp/123-arst')
        @dump.read_schema
      end

      it 'calls task db:schema:load and db:schema:dump' do
        @file = double('tempfile', :path => '/temp/123-arst')
        allow(@dump).to receive(:read_entry_to_file).and_yield(@file)

        @load_task = double('load_task')
        @dump_task = double('dump_task')
        expect(Rake::Task).to receive(:[]).with('db:schema:load').and_return(@load_task)
        expect(Rake::Task).to receive(:[]).with('db:schema:dump').and_return(@dump_task)
        expect(@load_task).to receive(:invoke)
        expect(@dump_task).to receive(:invoke)

        @dump.read_schema
      end
    end

    describe 'schema' do
      it 'reads schema' do
        @data = 'create table, rows, etc...'
        expect(@dump).to receive(:read_entry).with('schema.rb').and_return(@data)
        expect(@dump.schema).to eq(@data)
      end
    end

    describe 'read_tables' do
      it 'verifies connection' do
        allow(@dump).to receive(:config).and_return({:tables => []})
        expect(@dump).to receive(:verify_connection)
        @dump.read_tables
      end

      it 'calls read_table for each table in config' do
        allow(@dump).to receive(:verify_connection)
        allow(@dump).to receive(:config).and_return({:tables => {'first' => 1, 'second' => 3}})

        expect(@dump).to receive(:read_table).with('first', 1)
        expect(@dump).to receive(:read_table).with('second', 3)

        @dump.read_tables
      end

      describe 'when called with restore_tables' do
        it 'verifies connection and calls read_table for each table in restore_tables' do
          allow(@dump).to receive(:config).and_return({:tables => {'first' => 1, 'second' => 3}})

          expect(@dump).to receive(:verify_connection)
          expect(@dump).to receive(:read_table).with('first', 1)
          expect(@dump).not_to receive(:read_table).with('second', 3)

          Dump::Env.with_env(:restore_tables => 'first') do
            @dump.read_tables
          end
        end

        it 'does not verfiy connection or call read_table for empty restore_tables' do
          allow(@dump).to receive(:config).and_return({:tables => {'first' => 1, 'second' => 3}})

          expect(@dump).not_to receive(:verify_connection)
          expect(@dump).not_to receive(:read_table)

          Dump::Env.with_env(:restore_tables => '') do
            @dump.read_tables
          end
        end
      end
    end

    describe 'read_table' do
      it 'does not read table if no entry found for table' do
        expect(@dump).to receive(:find_entry).with('first.dump').and_return(nil)
        expect(@dump).not_to receive(:quote_table_name)
        @dump.read_table('first', 10)
      end

      it 'clears table and reads table if entry found for table' do
        @entry = double('entry', :to_str => Marshal.dump('data'), :eof? => true)
        expect(@dump).to receive(:columns_insert_sql).with('data')
        expect(@dump).to receive(:find_entry).with('first.dump').and_yield(@entry)
        expect(@dump).to receive(:quote_table_name).with('first').and_return('`first`')
        expect(@dump).to receive(:clear_table).with('`first`')
        @dump.read_table('first', 10)
      end

      it 'clears schema table before writing' do
        @entry = double('entry', :to_str => Marshal.dump('data'), :eof? => true)
        expect(@dump).to receive(:columns_insert_sql).with('data')
        expect(@dump).to receive(:find_entry).with('schema_migrations.dump').and_yield(@entry)
        expect(@dump).to receive(:quote_table_name).with('schema_migrations').and_return('`schema_migrations`')
        expect(@dump).to receive(:clear_table).with('`schema_migrations`')
        @dump.read_table('schema_migrations', 10)
      end

      describe 'reading/writing data' do
        def create_entry(rows_count)
          @entry = StringIO.new

          @columns = %w[id name]
          @rows = []
          Marshal.dump(@columns, @entry)
          (1..rows_count).each do |i|
            row = [i, "entry#{i}"]
            @rows << row
            Marshal.dump(row, @entry)
          end
          @entry.rewind

          allow(@dump).to receive(:find_entry).and_yield(@entry)
        end
        it 'reads to eof' do
          create_entry(2500)
          allow(@dump).to receive(:clear_table)
          allow(@dump).to receive(:insert_into_table)
          @dump.read_table('first', 2500)
          expect(@entry.eof?).to be_truthy
        end

        define :object_of_length do |n|
          match{ |actual| actual.length == n }
        end

        it 'tries to insert rows in slices of 1000 rows' do
          create_entry(2500)
          allow(@dump).to receive(:clear_table)
          expect(@dump).to receive(:insert_into_table).with(anything, anything, object_of_length(1000)).twice
          expect(@dump).to receive(:insert_into_table).with(anything, anything, object_of_length(500)).once

          @dump.read_table('first', 2500)
        end

        it 'tries to insert row by row if slice method fails' do
          create_entry(2500)
          allow(@dump).to receive(:clear_table)
          expect(@dump).to receive(:insert_into_table).with(anything, anything, kind_of(Array)).exactly(3).times.and_raise('sql error')
          expect(@dump).to receive(:insert_into_table).with(anything, anything, kind_of(String)).exactly(2500).times
          @dump.read_table('first', 2500)
        end

        it 'quotes table, columns and values and sends them to insert_into_table' do
          create_entry(100)
          allow(@dump).to receive(:clear_table)
          expect(@dump).to receive(:quote_table_name).with('first').and_return('`first`')
          expect(@dump).to receive(:columns_insert_sql).with(@columns).and_return('(`id`, `name`)')
          @rows.each do |row|
            expect(@dump).to receive(:values_insert_sql).with(row){ |vs| vs.inspect }
          end

          expect(@dump).to receive(:insert_into_table).with('`first`', '(`id`, `name`)', @rows.map(&:inspect))
          @dump.read_table('first', 100)
        end
      end
    end

    describe 'read_assets' do
      before do
        @task = double('task')
        allow(Rake::Task).to receive(:[]).with('assets:delete').and_return(@task)
        allow(@task).to receive(:invoke)
        allow(@dump).to receive(:assets_root_link).and_yield('/tmp', 'assets')
      end

      it 'does not read assets if config[:assets] is nil' do
        allow(@dump).to receive(:config).and_return({})
        expect(@dump).not_to receive(:find_entry)
        @dump.read_assets
      end

      it 'does not read assets if config[:assets] is blank' do
        allow(@dump).to receive(:config).and_return({:assets => []})
        expect(@dump).not_to receive(:find_entry)
        @dump.read_assets
      end

      describe 'deleting existing assets' do
        before do
          allow(@stream).to receive(:each)
        end

        it 'calls assets:delete' do
          @assets = %w[images videos]
          allow(@dump).to receive(:config).and_return({:assets => @assets})
          allow(@dump).to receive(:find_entry)

          expect(@task).to receive(:invoke)

          @dump.read_assets
        end

        it 'calls assets:delete with ASSETS set to config[:assets] joined with :' do
          @assets = %w[images videos]
          allow(@dump).to receive(:config).and_return({:assets => @assets})
          allow(@dump).to receive(:find_entry)

          expect(@task).to receive(:invoke) do
            expect(Dump::Env[:assets]).to eq('images:videos')
          end

          @dump.read_assets
        end

        describe 'when called with restore_assets' do
          it 'deletes files and dirs only in requested paths' do
            @assets = %w[images videos]
            allow(@dump).to receive(:config).and_return({:assets => @assets})

            expect(Dump::Assets).to receive('glob_asset_children').with('images', '**/*').and_return(%w[images images/a.jpg images/b.jpg])
            expect(Dump::Assets).to receive('glob_asset_children').with('videos', '**/*').and_return(%w[videos videos/a.mov])

            expect(@dump).to receive('read_asset?').with('images/b.jpg', Dump.rails_root).ordered.and_return(false)
            expect(@dump).to receive('read_asset?').with('images/a.jpg', Dump.rails_root).ordered.and_return(true)
            expect(@dump).to receive('read_asset?').with('images', Dump.rails_root).ordered.and_return(true)
            expect(@dump).to receive('read_asset?').with('videos/a.mov', Dump.rails_root).ordered.and_return(false)
            expect(@dump).to receive('read_asset?').with('videos', Dump.rails_root).ordered.and_return(false)

            expect(File).to receive('file?').with('images/a.jpg').and_return(true)
            expect(File).to receive('unlink').with('images/a.jpg')
            expect(File).not_to receive('file?').with('images/b.jpg')
            expect(File).to receive('file?').with('images').and_return(false)
            expect(File).to receive('directory?').with('images').and_return(true)
            expect(Dir).to receive('unlink').with('images').and_raise(Errno::ENOTEMPTY)

            Dump::Env.with_env(:restore_assets => 'images/a.*:stylesheets') do
              @dump.read_assets
            end
          end

          it 'does not delete any files and dirs for empty list' do
            @assets = %w[images videos]
            allow(@dump).to receive(:config).and_return({:assets => @assets})

            expect(Dump::Assets).not_to receive('glob_asset_children')

            expect(@dump).not_to receive('read_asset?')

            expect(File).not_to receive('directory?')
            expect(File).not_to receive('file?')
            expect(File).not_to receive('unlink')

            Dump::Env.with_env(:restore_assets => '') do
              @dump.read_assets
            end
          end
        end
      end

      describe 'old style' do
        it 'finds assets.tar' do
          @assets = %w[images videos]
          allow(@dump).to receive(:config).and_return({:assets => @assets})
          allow(Dir).to receive(:glob).and_return([])
          allow(FileUtils).to receive(:remove_entry)
          allow(@stream).to receive(:each)

          expect(@dump).to receive(:find_entry).with('assets.tar')
          @dump.read_assets
        end

        [
          %w[images videos],
          {'images' => 0, 'videos' => 0},
          {'images' => {:files => 0, :total => 0}, 'videos' => {:files => 0, :total => 0}},
        ].each do |assets|
          it 'rewrites rewind method to empty method - to not raise exception, opens tar and extracts each entry' do
            allow(@dump).to receive(:config).and_return({:assets => assets})
            allow(Dir).to receive(:glob).and_return([])
            allow(FileUtils).to receive(:remove_entry)

            @assets_tar = double('assets_tar')
            allow(@assets_tar).to receive(:rewind).and_raise('hehe - we want to rewind to center of gzip')
            allow(@dump).to receive(:find_entry).and_yield(@assets_tar)

            @inp = double('inp')
            each_excpectation = expect(@inp).to receive(:each)
            @entries = %w[a b c d].map do |s|
              file = double("file_#{s}")
              each_excpectation.and_yield(file)
              expect(@inp).to receive(:extract_entry).with(Dump.rails_root, file)
              file
            end
            expect(Archive::Tar::Minitar).to receive(:open).with(@assets_tar).and_yield(@inp)

            @dump.read_assets
          end
        end
      end

      describe 'new style' do
        before do
          expect(@dump).to receive(:find_entry).with('assets.tar')
        end

        [
          %w[images videos],
          {'images' => 0, 'videos' => 0},
          {'images' => {:files => 0, :total => 0}, 'videos' => {:files => 0, :total => 0}},
        ].each do |assets|
          it 'extracts each entry' do
            allow(@dump).to receive(:config).and_return({:assets => assets})
            allow(Dir).to receive(:glob).and_return([])
            allow(FileUtils).to receive(:remove_entry)

            expect(@dump).to receive(:assets_root_link).and_yield('/tmp/abc', 'assets')
            each_excpectation = expect(@stream).to receive(:each)
            @entries = %w[a b c d].map do |s|
              file = double("file_#{s}", :full_name => "assets/#{s}")
              each_excpectation.and_yield(file)
              expect(@stream).to receive(:extract_entry).with('/tmp/abc', file)
              file
            end
            other_file = double('other_file', :full_name => 'other_file')
            each_excpectation.and_yield(other_file)
            expect(@stream).not_to receive(:extract_entry).with('/tmp/abc', other_file)

            @dump.read_assets
          end
        end
      end
    end

    describe 'read_asset?' do
      it 'creates filter and call custom_pass? on it' do
        @filter = double('filter')
        allow(@filter).to receive('custom_pass?')

        expect(Dump::Env).to receive('filter').with(:restore_assets, Dump::Assets::SPLITTER).and_return(@filter)

        @dump.read_asset?('a', 'b')
      end

      it 'tests path usint fnmatch' do
        Dump::Env.with_env(:restore_assets => '[a-b]') do
          expect(@dump.read_asset?('x/a', 'x')).to be_truthy
          expect(@dump.read_asset?('x/b/file', 'x')).to be_truthy
          expect(@dump.read_asset?('x/c', 'x')).to be_falsey
        end
      end
    end
  end
end
