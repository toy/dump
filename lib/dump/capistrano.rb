# frozen_string_literal: true

require 'capistrano/version'

unless defined?(Capistrano::Version) && Capistrano::Version::MAJOR == 2
  fail 'Capistrano 3 is not yet supported'
end

require 'dump/capistrano/v2'
