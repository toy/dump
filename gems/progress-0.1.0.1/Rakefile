require 'rubygems'
require 'rake'
require 'rake/clean'
require 'fileutils'
require 'echoe'

load 'tasks/rspec.rake'

task :default => :spec
task :test

version = YAML.load_file(File.join(File.dirname(__FILE__), 'VERSION.yml')).join('.') rescue nil

echoe = Echoe.new('progress', version) do |p|
  p.author = "toy"
  p.summary = "A library to show progress of long running tasks."
end

desc "Replace system gem with symlink to this folder"
task 'ghost' do
  path = Gem.searcher.find(echoe.name).full_gem_path
  system 'sudo', 'rm', '-r', path
  symlink File.expand_path('.'), path
end
