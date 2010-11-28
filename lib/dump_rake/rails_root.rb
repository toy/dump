# encoding: utf-8
class DumpRake
  RailsRoot = (Object.const_defined?('Rails') ? Rails.root : RAILS_ROOT).to_s
end
