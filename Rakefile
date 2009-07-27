require 'rake'
require 'spec/rake/spectask'

desc 'Default: run specs.'
task :default => :spec_with_rcov_and_open

desc 'Run the specs'
Spec::Rake::SpecTask.new(:spec) do |t|
  t.spec_opts = ['--colour --format progress --loadby mtime --reverse']
  t.spec_files = FileList['spec/**/*_spec.rb']
end

desc 'Run the specs with RCov'
Spec::Rake::SpecTask.new(:spec_with_rcov) do |t|
  t.spec_opts = ['--colour --format progress --loadby mtime --reverse']
  t.spec_files = FileList['spec/**/*_spec.rb']
  t.rcov = true
  t.rcov_opts = ['--exclude', '^/,spec,gems']
end

task :spec_with_rcov_and_open => :spec_with_rcov do
  `open coverage/index.html`
end
