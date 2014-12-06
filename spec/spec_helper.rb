ENV['RAILS_ENV'] ||= 'test'

require 'rails/version'

rails_version = Rails::VERSION::STRING.split('.')

if rails_version[0].to_i < 3 && !Gem.respond_to?(:source_index)
  module Gem
    def self.source_index; sources; end
    SourceIndex = Specification
  end
end

environment_paths = (1..rails_version.length).map do |count|
  version_part = rails_version[0, count].join('.')
  File.expand_path("../dummy-#{version_part}/config/environment", __FILE__)
end.reverse

environment_paths.any? do |environment_path|
  if File.exist?("#{environment_path}.rb")
    require environment_path
    true
  end
end || begin
  command = "RAILS_VERSION=#{rails_version.join('.')} bundle exec rails " + if rails_version[0].to_i < 3
    "spec/dummy-#{rails_version[0, 2].join('.')}"
  else
    "new spec/dummy-#{rails_version[0, 2].join('.')} -TSJ --skip-bundle"
  end

  abort [
    "No dummy app for rails version #{rails_version.join('.')}",
    "Create using `#{command}`",
    'Tried:', *environment_paths
  ].join("\n")
end

$:.unshift '../lib/dump_rake'
require 'dump_rake'

PLUGIN_SPEC_DIR = File.expand_path(File.dirname(__FILE__)) unless defined? PLUGIN_SPEC_DIR
ActiveRecord::Base.logger = Logger.new(File.join(DumpRake::RailsRoot, 'log/dump.log'))

DUMMY_SCHEMA_PATH = File.join(PLUGIN_SPEC_DIR, 'db', 'schema.rb') unless defined? DUMMY_SCHEMA_PATH

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
