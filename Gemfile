# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

gem 'rake', '< 12.3' if RUBY_VERSION < '2.0'

if RUBY_VERSION < '2.3'
  gem 'appraisal', '< 2.3'
else
  gem 'appraisal', :git => 'https://github.com/toy/appraisal.git', :branch => 'ruby-3.2-fix-1'
end
