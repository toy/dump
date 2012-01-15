require 'rake'
require 'rake/gem_ghost_task'
require 'rspec/core/rake_task'

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
