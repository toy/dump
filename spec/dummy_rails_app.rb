# frozen_string_literal: true

require 'rails/version'

version = Rails::VERSION::STRING

if version < '3' && !Gem.respond_to?(:source_index)
  # Add Gem.source_index for rails < 3
  module Gem
    def self.source_index
      sources
    end
    SourceIndex = Specification
  end
end

# Construct possible paths for config/environment.rb in dummy-X.X.X,
# dummy-X.X, dummy-X
version_parts = version.split('.')
environment_paths = version_parts.length.downto(1).map do |count|
  version_part = version_parts.take(count).join('.')
  File.expand_path("../dummy-#{version_part}/config/environment.rb", __FILE__)
end

# Require environment if any dummy app exists, otherwise abort with instructions
if (environment_path = environment_paths.find(&File.method(:exist?)))
  require environment_path
else
  app_path = "spec/dummy-#{version_parts.take(2).join('.')}"

  command = if version < '3'
    "rails _#{version}_ #{app_path}"
  else
    "rails _#{version}_ new #{app_path} -TSJ --skip-bundle"
  end

  abort [
    "No dummy app for rails #{version}",
    "Create using `#{command}`",
    'Tried:', *environment_paths
  ].join("\n")
end
