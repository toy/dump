# encoding: utf-8
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
