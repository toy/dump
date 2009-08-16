# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{progress}
  s.version = "0.0.9.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 1.2") if s.respond_to? :required_rubygems_version=
  s.authors = ["toy"]
  s.date = %q{2009-08-06}
  s.description = %q{A library to show progress of long running tasks.}
  s.email = %q{}
  s.extra_rdoc_files = ["CHANGELOG", "lib/progress/enumerable.rb", "lib/progress/integer.rb", "lib/progress/with_progress.rb", "lib/progress.rb", "README.rdoc", "tasks/rspec.rake"]
  s.files = ["CHANGELOG", "lib/progress/enumerable.rb", "lib/progress/integer.rb", "lib/progress/with_progress.rb", "lib/progress.rb", "Manifest", "Rakefile", "README.rdoc", "spec/progress_spec.rb", "spec/spec.opts", "spec/spec_helper.rb", "tasks/rspec.rake", "VERSION.yml", "progress.gemspec"]
  s.homepage = %q{}
  s.rdoc_options = ["--line-numbers", "--inline-source", "--title", "Progress", "--main", "README.rdoc"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{progress}
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{A library to show progress of long running tasks.}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
