require 'spec_helper'
require 'dump'
require 'tmpdir'

class Chicken < ActiveRecord::Base
end

ActiveRecord::Base.logger = Logger.new(File.join(Dump.rails_root, 'log/dump.log'))

def database_configs
  YAML.load(IO.read(File.expand_path('../db/database.yml', __FILE__)))
end

def adapters
  database_configs.keys
end

def use_adapter(adapter)
  config = database_configs[adapter]
  begin
    case config['adapter']
    when /^mysql/
      ActiveRecord::Base.establish_connection(config.merge('database' => nil))
      ActiveRecord::Base.connection.drop_database config['database']
      ActiveRecord::Base.connection.create_database(config['database'])
      ActiveRecord::Base.establish_connection(config)
    when /^postgresql/
      ActiveRecord::Base.establish_connection(config.merge('database' => 'postgres', 'schema_search_path' => 'public'))
      ActiveRecord::Base.connection.drop_database config['database']
      ActiveRecord::Base.connection.create_database(config['database'])
      ActiveRecord::Base.establish_connection(config)
    else
      ActiveRecord::Base.establish_connection(config)
    end
    load_schema
    yield
  ensure
    case config['adapter']
    when /^mysql/
      ActiveRecord::Base.establish_connection(config)
      ActiveRecord::Base.connection.drop_database config['database']
    when /^postgresql/
      ActiveRecord::Base.establish_connection(config.merge('database' => 'postgres', 'schema_search_path' => 'public'))
      ActiveRecord::Base.connection.drop_database config['database']
    end
  end
ensure
  ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => ':memory:')
end

def schema_path
  File.expand_path('../db/schema.rb', __FILE__)
end

def load_schema
  grab_output do
    load(schema_path)
  end
end

def create_chickens!(options = {})
  time = Time.local(2000, 'jan', 1, 20, 15, 1)
  data = {
    :string => ['', 'lala'],
    :text => ['', 'lala', 'lala' * 100],
    :integer => [-1000, 0, 1000],
    :float => [-1000.0, 0.0, 1000.0],
    :decimal => [-1000.0, 0.0, 1000.0],
    :datetime => [time, time - 5.years],
    :timestamp => [time, time - 5.years],
    :time => [time, time - 5.years],
    :date => [time, time - 5.years],
    :boolean => [true, false],
  }
  Chicken.create!
  data.values.map(&:length).max.times do |i|
    Chicken.create! do |chicken|
      data.each do |type, values|
        chicken["#{type}_col"] = values[i]
      end
    end
  end
  options[:random].to_i.times do
    Chicken.create! do |chicken|
      data.each do |type, values|
        chicken["#{type}_col"] = values[rand(values.length)] if rand > 0.5
      end
    end
  end
end

def chicken_data
  Chicken.all.map(&:attributes).sort_by{ |attributes| attributes['id'] }
end

def reset_rake!
  @rake = Rake::Application.new
  Rake.application = @rake
  load 'tasks/assets.rake'
  load 'tasks/dump.rake'
  Rake::Task.define_task('environment')
  Rake::Task.define_task('db:schema:dump') do
    File.open(schema_path, 'r') do |r|
      if ENV['SCHEMA']
        File.open(ENV['SCHEMA'], 'w') do |w|
          w.write(r.read)
        end
      end
    end
  end
  Rake::Task.define_task('db:schema:load') do
    load(ENV['SCHEMA'])
  end
end

def call_rake
  reset_rake!
  grab_output do
    yield
  end
end

def call_rake_create(*args)
  call_rake do
    Dump.create(*args)
  end
end

def call_rake_restore(*args)
  call_rake do
    Dump.restore(*args)
  end
end

describe 'full cycle' do
  around do |example|
    Dir.mktmpdir do |dir|
      @tmp_dir = dir
      example.run
    end
  end
  before do
    allow(Dump).to receive(:rails_root).and_return(@tmp_dir)
    allow(Progress).to receive(:io).and_return(StringIO.new)
  end

  begin
    database_configs

    adapters.each do |adapter|
      it "should dump and restore using #{adapter}" do
        use_adapter(adapter) do
          # add chickens store their attributes and create dump
          create_chickens!(:random => 100)
          saved_chicken_data = chicken_data
          call_rake_create(:description => 'chickens')

          # clear database
          load_schema
          expect(Chicken.all).to eq([])

          # restore dump and verify equality
          call_rake_restore(:version => 'chickens')
          expect(chicken_data).to eq(saved_chicken_data)

          # go throught create/restore cycle and verify equality
          call_rake_create
          load_schema
          expect(Chicken.all).to be_empty
          call_rake_restore
          expect(chicken_data).to eq(saved_chicken_data)
        end
      end
    end

    adapters.each do |adapter|
      it "should not break id incrementing using #{adapter}" do
        use_adapter(adapter) do
          create_chickens!(:random => 100)
          call_rake_create(:description => 'chickens')
          load_schema
          call_rake_restore(:version => 'chickens')
          create_chickens!
        end
      end
    end

    adapters.combination(2) do |adapter_src, adapter_dst|
      it "should dump using #{adapter_src} and restore using #{adapter_dst}" do
        saved_chicken_data = nil
        use_adapter(adapter_src) do
          expect(Chicken.all).to be_empty

          create_chickens!(:random => 100)
          saved_chicken_data = chicken_data
          call_rake_create
        end

        use_adapter(adapter_dst) do
          expect(Chicken.all).to be_empty

          call_rake_restore
          expect(chicken_data).to eq(saved_chicken_data)
        end
      end
    end

    it 'should create same dump for all adapters' do
      dumps = []
      adapters.each do |adapter|
        use_adapter(adapter) do
          dump_name = call_rake_create(:desc => adapter)[:stdout].strip
          dump_path = File.join(Dump.rails_root, 'dump', dump_name)

          data = []
          Zlib::GzipReader.open(dump_path) do |gzip|
            Archive::Tar::Minitar.open(gzip, 'r') do |stream|
              stream.each do |entry|
                entry_data = if entry.full_name == 'schema.rb'
                  entry.read
                else
                  Marshal.load(entry.read)
                end
                data << [entry.full_name, entry_data]
              end
            end
          end
          dumps << {:path => dump_path, :data => data.sort}
        end
      end

      dumps.combination(2) do |dump_a, dump_b|
        expect(dump_a[:path]).not_to eq(dump_b[:path])
        expect(dump_a[:data]).to eq(dump_b[:data])
      end
    end
  rescue Errno::ENOENT => e
    $stderr.puts e
  end
end
