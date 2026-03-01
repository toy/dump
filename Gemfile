# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

gem 'rake', '< 12.3' if RUBY_VERSION < '2.0'

gem 'appraisal', *RUBY_VERSION < '2.3' ? ['< 2.3'] : ['>= 2.5']

if RUBY_VERSION >= '4'
  gem 'benchmark'
end
