begin
  require File.join(File.dirname(__FILE__), 'dummy-3.1.3/spec/spec_helper')
rescue LoadError => e
  abort e
end

$:.unshift '../lib/dump_rake'
require 'dump_rake'

RSpec.configure do |config|
  config.use_transactional_fixtures = false
  config.use_instantiated_fixtures  = false
  config.fixture_path = DumpRake::RailsRoot + '/spec/fixtures/'
end

PLUGIN_SPEC_DIR = File.expand_path(File.dirname(__FILE__)) unless defined? PLUGIN_SPEC_DIR
ActiveRecord::Base.logger = Logger.new(File.join(DumpRake::RailsRoot, 'log/dump-plugin-debug.log'))

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
