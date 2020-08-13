# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

gem 'appraisal', *RUBY_VERSION < '2.3' ? ['< 2.3'] : []

if ENV['CHECK_RUBIES']
  gem 'travis_check_rubies', '~> 0.2'
end
