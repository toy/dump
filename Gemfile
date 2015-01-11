source 'http://rubygems.org'

rails_version = ENV['RAILS_VERSION'] || '~> 4.0'
gem 'rails', rails_version

if defined?(JRUBY_VERSION)
  gem 'activerecord-jdbcsqlite3-adapter'
  gem 'activerecord-jdbcmysql-adapter'
  gem 'activerecord-jdbcpostgresql-adapter'
else
  gem 'sqlite3'
  gem 'mysql2'
  if RUBY_VERSION == '1.8.7'
    gem 'pg', '0.17.1'
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

gemspec
