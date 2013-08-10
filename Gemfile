source 'http://rubygems.org'

gem 'rails', '3.1.3'

if defined?(JRUBY_VERSION)
  gem 'activerecord-jdbcsqlite3-adapter'
  gem 'activerecord-jdbcmysql-adapter'
  gem 'activerecord-jdbcpostgresql-adapter'
else
  gem 'sqlite3'
  gem 'mysql2'
  gem 'pg'
end

gem 'capistrano'
gemspec
