# encoding: UTF-8

Gem::Specification.new do |s|
  s.name        = 'dump'
  s.version     = '1.0.6'
  s.summary     = %q{Rails app rake and capistrano tasks to create and restore dumps of database and assets}
  s.homepage    = "http://github.com/toy/#{s.name}"
  s.authors     = ['Ivan Kuchin']
  s.license     = 'MIT'

  s.rubyforge_project = s.name

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = %w[lib]

  s.add_dependency 'archive-tar-minitar', '= 0.5.2'
  s.add_dependency 'progress', '~> 3.0', '>= 3.0.1'
  s.add_development_dependency 'rspec', '~> 3.0'
  if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('1.9.3')
    s.add_development_dependency 'rubocop', '~> 0.27'
  end
end
