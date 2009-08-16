require File.dirname(__FILE__) + '/spec_helper'

def database_configs
  YAML::load(IO.read(PLUGIN_SPEC_DIR + "/db/database.yml"))
end

def adapters
  database_configs.keys
end

def use_adapter(adapter = nil)
  ActiveRecord::Base.establish_connection(database_configs[adapter || "sqlite3"])
  load_schema
end

def load_schema
  grab_output{
    load(DUMMY_SCHEMA_PATH)
  }
end

def in_temp_rails_app
  old_rails_root = RAILS_ROOT.dup
  RAILS_ROOT.replace(File.join(PLUGIN_SPEC_DIR, 'temp_rails_app'))
  FileUtils.remove_entry_secure(RAILS_ROOT) if File.exist?(RAILS_ROOT)
  FileUtils.mkpath(RAILS_ROOT)
  yield
ensure
  FileUtils.remove_entry_secure(RAILS_ROOT) if File.exist?(RAILS_ROOT)
  RAILS_ROOT.replace(old_rails_root)
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
    :binary => [(1..255).to_a.pack('c*')],
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
        attributes["#{type}_col"] = values.rand if rand > 0.5
      end
      Chicken.create!(attributes)
    end
  end
end

def reset_rake!
  @rake = Rake::Application.new
  Rake.application = @rake
  load File.dirname(__FILE__) + '/../tasks/assets.rake'
  load File.dirname(__FILE__) + '/../tasks/dump.rake'
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
          use_adapter(adapter)

          #add chickens store their attributes and create dump
          create_chickens!(:random => 100)
          chicken_attributes = Chicken.all.map(&:attributes)
          call_rake_create(:description => 'chickens')

          #clear database
          load_schema
          Chicken.all.should == []

          #restore dump and verify equality
          call_rake_restore('chickens')
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

    adapters.each do |adapter_src|
      adapters.each do |adapter_dst|
        next if adapter_src == adapter_dst
        it "should dump using #{adapter_src} and restore using #{adapter_dst}" do
          in_temp_rails_app do
            use_adapter(adapter_src)
            Chicken.all.should be_empty

            create_chickens!(:random => 100)
            chicken_attributes = Chicken.all.map(&:attributes)
            call_rake_create

            use_adapter(adapter_dst)
            Chicken.all.should be_empty

            call_rake_restore
            chicken_attributes.should == Chicken.all.map(&:attributes)
          end
        end
      end
    end

    it "should create same dump for all adapters" do
      in_temp_rails_app do
        adapters.each do |adapter|
          use_adapter(adapter)
          load_schema
          call_rake_create(:description => adapter)
        end

        dumps = {}
        Dump.list.each do |dump|
          dumps[dump.name] = {
            :path => dump.path,
            :hash => Digest::SHA1.hexdigest(File.read(dump.path)),
          }
        end

        dumps.keys.each do |dump_a|
          dumps.keys.each do |dump_b|
            next unless dump_a < dump_b
            dumps[dump_a][:path].should_not == dumps[dump_b][:path]
            dumps[dump_a][:hash].should == dumps[dump_b][:hash]
          end
        end
      end
    end
  rescue Errno::ENOENT => e
    $stderr.puts e
    it "create database.yml from example to run all tests"
  end
end
