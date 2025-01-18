ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.

require 'logger' # fix rails relying on concurrent-ruby < 1.3.5 to require logger?
