require File.dirname(__FILE__) + '/spec_helper'

require File.dirname(__FILE__) + '/../lib/dump_rake'

def database_configs
  YAML::load(IO.read(PLUGIN_SPEC_DIR + "/db/database.yml"))
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
      ActiveRecord::Base.connection.create_database(config['database'])
      ActiveRecord::Base.establish_connection(config)
    when /^postgresql/
      ActiveRecord::Base.establish_connection(config.merge('database' => 'postgres', 'schema_search_path' => 'public'))
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

def load_schema
  grab_output{
    load(DUMMY_SCHEMA_PATH)
  }
end

def in_temp_rails_app
  old_rails_root = DumpRake::RailsRoot.dup
  DumpRake::RailsRoot.replace(File.join(PLUGIN_SPEC_DIR, 'temp_rails_app'))
  FileUtils.remove_entry(DumpRake::RailsRoot) if File.exist?(DumpRake::RailsRoot)
  FileUtils.mkpath(DumpRake::RailsRoot)
  Progress.stub!(:io).and_return(StringIO.new)
  yield
ensure
  FileUtils.remove_entry(DumpRake::RailsRoot) if File.exist?(DumpRake::RailsRoot)
  DumpRake::RailsRoot.replace(old_rails_root)
end

def create_chickens!(options = {})
  time = Time.local(2000,"jan",1,20,15,1)
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
  data.each do |type, values|
    values.each do |value|
      Chicken.create!("#{type}_col" => value)
    end
  end
  if options[:random]
    options[:random].to_i.times do
      attributes = {}
      data.each do |type, values|
        attributes["#{type}_col"] = values[rand(values.length)] if rand > 0.5
      end
      Chicken.create!(attributes)
    end
  end
end

def reset_rake!
  @rake = Rake::Application.new
  Rake.application = @rake
  load File.dirname(__FILE__) + '/../lib/tasks/assets.rake'
  load File.dirname(__FILE__) + '/../lib/tasks/dump.rake'
  Rake::Task.define_task('environment')
  Rake::Task.define_task('db:schema:dump') do
    File.open(DUMMY_SCHEMA_PATH, 'r') do |r|
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
  grab_output{
    yield
  }
end

def call_rake_create(*args)
  call_rake{
    DumpRake.create(*args)
  }
end

def call_rake_restore(*args)
  call_rake{
    DumpRake.restore(*args)
  }
end

describe 'full cycle' do
  begin
    database_configs

    adapters.each do |adapter|
      it "should dump and restore using #{adapter}" do
        in_temp_rails_app do
          use_adapter(adapter) do
            #add chickens store their attributes and create dump
            create_chickens!(:random => 100)
            chicken_attributes = Chicken.all.map(&:attributes)
            call_rake_create(:description => 'chickens')

            #clear database
            load_schema
            Chicken.all.should == []

            #restore dump and verify equality
            call_rake_restore(:version => 'chickens')
            Chicken.all.map(&:attributes).should == chicken_attributes

            # go throught create/restore cycle and verify equality
            call_rake_create
            load_schema
            Chicken.all.should be_empty
            call_rake_restore
            Chicken.all.map(&:attributes).should == chicken_attributes
          end
        end
      end
    end

    adapters.each do |adapter|
      it "should not break id incrementing using #{adapter}" do
        in_temp_rails_app do
          use_adapter(adapter) do
            create_chickens!(:random => 100)
            call_rake_create(:description => 'chickens')
            load_schema
            call_rake_restore(:version => 'chickens')
            create_chickens!
          end
        end
      end
    end

    adapters.combination(2) do |adapter_src, adapter_dst|
      it "should dump using #{adapter_src} and restore using #{adapter_dst}" do
        in_temp_rails_app do
          chicken_attributes = nil
          use_adapter(adapter_src) do
            Chicken.all.should be_empty

            create_chickens!(:random => 100)
            chicken_attributes = Chicken.all.map(&:attributes)
            call_rake_create
          end

          use_adapter(adapter_dst) do
            Chicken.all.should be_empty

            call_rake_restore
            chicken_attributes.should == Chicken.all.map(&:attributes)
          end
        end
      end
    end

    it "should create same dump for all adapters" do
      in_temp_rails_app do
        dumps = []
        adapters.each do |adapter|
          use_adapter(adapter) do
            dump_name = call_rake_create(:desc => adapter)[:stdout].strip
            dump_path = File.join(DumpRake::RailsRoot, 'dump', dump_name)

            data = []
            Zlib::GzipReader.open(dump_path) do |gzip|
              Archive::Tar::Minitar.open(gzip, 'r') do |stream|
                stream.each do |entry|
                  data << [entry.full_name, entry.read]
                end
              end
            end
            dumps << {:path => dump_path, :data => data.sort}
          end
        end

        dumps.combination(2) do |dump_a, dump_b|
          dump_a[:path].should_not == dump_b[:path]
          dump_a[:data].should == dump_b[:data]
        end
      end
    end
  rescue Errno::ENOENT => e
    $stderr.puts e
  end
end
