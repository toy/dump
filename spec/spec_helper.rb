begin
  require File.dirname(__FILE__) + '/../../../../spec/spec_helper'
rescue LoadError
  puts "You need to install rspec in your base app"
  exit
end

plugin_spec_dir = File.dirname(__FILE__)
ActiveRecord::Base.logger = Logger.new(plugin_spec_dir + "/debug.log")

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
