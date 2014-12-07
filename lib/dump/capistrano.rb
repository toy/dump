require 'capistrano/version'

if defined?(Capistrano::Version) && Capistrano::Version::MAJOR == 2
  require 'dump/capistrano/v2'
else
  fail 'Capistrano 3 is not yet supported'
end
