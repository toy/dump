require 'pathname'
require 'rubygems'
require 'rake'
require 'rake/clean'
require 'fileutils'
require 'echoe'

version = YAML.load_file(Pathname(__FILE__).dirname + 'VERSION.yml').join('.') rescue nil

echoe = Echoe.new('progress', version) do |p|
  p.author = 'toy'
  p.summary = 'A library to show progress of long running tasks.'
end

desc "Replace system gem with symlink to this folder"
task 'ghost' do
  gem_path = Pathname(Gem.searcher.find(echoe.name).full_gem_path)
  current_path = Pathname('.').expand_path
  cmd = gem_path.writable? && gem_path.parent.writable? ? %w() : %w(sudo)
  system(*cmd + %W[rm -r #{gem_path}])
  system(*cmd + %W[ln -s #{current_path} #{gem_path}])
end
