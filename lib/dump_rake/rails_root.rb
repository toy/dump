# encoding: UTF-8

# Get rails app root (Rails.root or RAILS_ROOT or Dir.pwd)
class DumpRake
  RailsRoot = case
  when defined?(Rails)
    Rails.root
  when defined?(RAILS_ROOT)
    RAILS_ROOT
  else
    Dir.pwd
  end.to_s
end
