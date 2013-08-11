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
  gem 'pg'
  if rails_version =~ /(^|[^.\d])(2|3\.0)\.\d+/
    gem 'activerecord-mysql2-adapter'
    gem 'activerecord-postgresql-adapter'
  end
end

gem 'capistrano'
gemspec
