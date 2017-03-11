source 'http://rubygems.org'

rails_version = ENV['RAILS_VERSION'] || '~> 4.0'
gem 'rails', rails_version

if defined?(JRUBY_VERSION)
  gem 'activerecord-jdbcsqlite3-adapter'
  gem 'activerecord-jdbcmysql-adapter'
  gem 'activerecord-jdbcpostgresql-adapter'
else
  gem 'sqlite3'
  gem 'mysql2', '~> 0.3.10'
  if RUBY_VERSION < '1.9'
    gem 'pg', '0.17.1'
    gem 'i18n', '0.6.11'
    gem 'highline', '~> 1.6.21'
  else
    gem 'pg'
  end
  if rails_version =~ /(^|[^.\d])(2|3\.0)\.\d+/
    gem 'activerecord-mysql2-adapter'
  end
  if rails_version =~ /(^|[^.\d])2\.\d+/ && RUBY_VERSION >= '2.0'
    gem 'iconv', '~> 1.0.4'
  end
end

gem 'capistrano', '~> 2.0'

gem 'net-ssh', '< 3' if RUBY_VERSION < '2.0'
gem 'rake', '< 11' if RUBY_VERSION < '1.9'
gem 'mime-types', '< 3' if RUBY_VERSION < '2.0' && RUBY_VERSION >= '1.9'
gem 'rack-cache', '< 1.3' if RUBY_VERSION < '1.9'

gemspec

gem 'travis_check_rubies', '~> 0.1'
