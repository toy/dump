module Dump
  class Railtie < Rails::Railtie
    rake_tasks do
      load "tasks/assets.rake"
      load "tasks/dump.rake"
    end
  end
end
