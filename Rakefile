require 'rake'
require 'jeweler'
require 'rake/gem_ghost_task'
require 'rspec/core/rake_task'

name = 'dump'

Jeweler::Tasks.new do |gem|
  gem.name = name
  gem.summary = %Q{Rails app rake and capistrano tasks to create and restore dumps of database and assets}
  gem.homepage = "http://github.com/toy/#{name}"
  gem.license = 'MIT'
  gem.authors = ['Ivan Kuchin']
  gem.add_development_dependency 'jeweler', '~> 1.5.1'
  gem.add_development_dependency 'rake-gem-ghost'
  gem.add_development_dependency 'rspec'
end
Jeweler::RubygemsDotOrgTasks.new
Rake::GemGhostTask.new

RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.rspec_opts = ['--colour --format progress']
  spec.pattern = 'spec/**/*_spec.rb'
end

RSpec::Core::RakeTask.new(:rcov) do |spec|
  spec.rspec_opts = ['--colour --format progress']
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
  # t.rcov_opts = ['--exclude', '^/,spec,gems,lib/shell_escape,lib/continious_timeout']
end

task :spec_with_rcov_and_open => :rcov do
  `open coverage/index.html`
end

desc 'Default: run specs.'
task :default => :spec_with_rcov_and_open

# desc 'update readme from env'
# task :update_readme do
#   $: << File.join(File.dirname(__FILE__), 'lib')
#   require 'pathname'
#   require 'dump_rake'
#
#   readme = Pathname('README.rdoc')
#   lines = readme.readlines.map(&:rstrip)
#   readme.open('w') do |f|
#     lines.each do |line|
#       line.sub!(/^<tt>(.+?)<\/tt>.*—.*$/) do
#         key, names = DumpRake::Env::DICTIONARY.find{ |key, values| values.include?($1) }
#         if key
#           names = names.map{ |name| "<tt>#{name}</tt>" }.join(', ')
#           explanation = DumpRake::Env::EXPLANATIONS[key]
#           "#{names} — #{explanation}"
#         end
#       end
#       f.puts line
#     end
#   end
# end
