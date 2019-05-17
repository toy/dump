# frozen_string_literal: true

module Dump
  # Add rake tasks to rails app
  class Railtie < Rails::Railtie
    rake_tasks do
      load 'tasks/assets.rake'
      load 'tasks/dump.rake'
    end
  end
end
