def appgen(gems)
  description = gems.map{ |name, version| "#{name} #{version}" }.join(', ')
  appraise description do
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
    else
      gem 'sqlite3'

      case
      when rails_version =~ /^2\./
        gem 'mysql2', '~> 0.3.10'
        gem 'activerecord-mysql2-adapter'
      when rails_version =~ /^3\./
        gem 'mysql2', '~> 0.3.10'
      when rails_version =~ /^4\./
        gem 'mysql2', '>= 0.3.13', '< 0.5'
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
      else
        gem 'pg'
      end
    end
  end
end

if RUBY_VERSION < '2.0'
  appgen 'rails' => '~> 2.3'
end

if RUBY_VERSION < '2.3'
  appgen 'rails' => '~> 3.2'
end

if RUBY_VERSION >= '1.9'
  appgen 'rails' => '~> 4.2'
end

if RUBY_VERSION >= '2.2'
  appgen 'rails' => '~> 5.0.0'
  appgen 'rails' => '~> 5.1.0'
  appgen 'rails' => '~> 5.2'
end