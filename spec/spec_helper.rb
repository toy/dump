begin
  require File.dirname(__FILE__) + '/../../../../spec/spec_helper'
rescue LoadError
  puts "You need to install rspec in your base app"
  exit
end

Spec::Runner.configure do |config|
  config.use_transactional_fixtures = false
  config.use_instantiated_fixtures  = false
  config.fixture_path = RAILS_ROOT + '/spec/fixtures/'
end

PLUGIN_SPEC_DIR = File.expand_path(File.dirname(__FILE__)) unless defined? PLUGIN_SPEC_DIR
ActiveRecord::Base.logger = Logger.new(PLUGIN_SPEC_DIR + "/debug.log")

DUMMY_SCHEMA_PATH = File.join(PLUGIN_SPEC_DIR, "db", "schema.rb") unless defined? DUMMY_SCHEMA_PATH

class Chicken < ActiveRecord::Base
end

def with_env(key, value)
  old_value, ENV[key] = ENV[key], value
  yield
ensure
  ENV[key] = old_value
end

def grab_output
  old_value, $stdout = $stdout, StringIO.new
  yield
  $stdout.string
ensure
  $stdout = old_value
end
