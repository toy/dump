# frozen_string_literal: true

def appgen(gems) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
  description = gems.map{ |name, version| "#{name} #{version}" }.join(', ')
  appraise "ruby-#{RUBY_VERSION[/\d+\.\d+/]} #{description}" do
    rails_version = gems['rails'][/\d+(\.\d+)+/]

    gems.each do |name, version|
      gem name, version
    end

    gem 'capistrano', '~> 2.0'

    gem 'concurrent-ruby', '!= 1.1.1' if RUBY_VERSION =~ /^1\.9\./

    if defined?(JRUBY_VERSION)
      gem 'activerecord-jdbcsqlite3-adapter'
      gem 'activerecord-jdbcmysql-adapter'
      gem 'activerecord-jdbcpostgresql-adapter'

      if rails_version[/\d+/].to_i < 5
        gem 'activerecord-jdbc-adapter', '~> 1.3.0'
      else
        gem 'activerecord-jdbc-adapter', "~> #{rails_version.scan(/\d+/).take(2).join('')}.0"
      end
    else
      case
      when rails_version =~ /^[2345]\./
        gem 'sqlite3', '~> 1.3.5'
      when RUBY_VERSION < '2.7'
        gem 'sqlite3', '< 1.6'
      when RUBY_VERSION < '3.0'
        gem 'sqlite3', '< 1.7'
      when rails_version < '7.1'
        gem 'sqlite3', '~> 1.4'
      else
        gem 'sqlite3'
      end

      case
      when rails_version =~ /^2\./
        gem 'mysql2', '~> 0.3.13'
        gem 'activerecord-mysql2-adapter'
      when rails_version =~ /^3\.|^4\.[01]\./
        gem 'mysql2', '~> 0.3.13'
      when rails_version =~ /^4\./
        gem 'mysql2', '~> 0.4.0'
      else
        gem 'mysql2'
      end

      case
      when RUBY_VERSION < '1.9'
        gem 'pg', '~> 0.17.1'
      when rails_version =~ /^3\./
        gem 'pg', '~> 0.11'
      when rails_version =~ /^4\./
        gem 'pg', '~> 0.15'
      when RUBY_VERSION < '3'
        gem 'pg', '< 1.6.1'
      else
        gem 'pg'
      end

      if RUBY_VERSION < '2.0'
        gem 'rake', '< 12.3'
        gem 'rails-html-sanitizer', '< 1.5' if rails_version >= '4.2'
      end

      if RUBY_VERSION >= '3.0'
        gem 'sorted_set'
        gem 'net-smtp'
      end

      if RUBY_VERSION >= '3.4'
        gem 'base64'
        gem 'bigdecimal'
        gem 'mutex_m'
      end

      if RUBY_VERSION < '2.5'
        gem 'loofah', '< 2.21.0'
      end
    end
  end
end

appgen 'rails' => '~> 2.3.0' if RUBY_VERSION < '2.0'

appgen 'rails' => '~> 3.1.0' if RUBY_VERSION < '2.0'
appgen 'rails' => '~> 3.2.0' if RUBY_VERSION < '2.4'

appgen 'rails' => '~> 4.0.0' if RUBY_VERSION >= '1.9' && RUBY_VERSION < '2.3'
appgen 'rails' => '~> 4.1.0' if RUBY_VERSION >= '1.9' && RUBY_VERSION < '2.4'
appgen 'rails' => '~> 4.2.0' if RUBY_VERSION >= '1.9' && RUBY_VERSION < '2.5'

appgen 'rails' => '~> 5.0.0' if RUBY_VERSION >= '2.3' && RUBY_VERSION < '2.5'
appgen 'rails' => '~> 5.1.0' if RUBY_VERSION >= '2.3' && RUBY_VERSION < '2.6'
appgen 'rails' => '~> 5.2.0' if RUBY_VERSION >= '2.3' && RUBY_VERSION < '3.0'

appgen 'rails' => '~> 6.0.0' if RUBY_VERSION >= '2.5' && RUBY_VERSION < '3.1'
appgen 'rails' => '~> 6.1.0' if RUBY_VERSION >= '2.5'
