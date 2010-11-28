require 'pathname'
require 'fileutils'

require (Pathname(__FILE__).dirname + 'lib/dump_rake/rails_root')

assets_template = Pathname(__FILE__).dirname + 'assets.example'
assets_config = Pathname(DumpRake::RailsRoot) + 'config/assets'

unless assets_config.exist?
  FileUtils.cp(assets_template, assets_config, :verbose => true)
  puts "Created assets file with default path of public/system"
end
