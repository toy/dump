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

def grab_output
  real_stdout, $stdout = $stdout, StringIO.new
  real_stderr, $stderr = $stderr, StringIO.new
  begin
    yield
    {:stdout => $stdout.string, :stderr => $stderr.string}
  ensure
    $stdout = real_stdout
    $stderr = real_stderr
  end
end
