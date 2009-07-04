require 'pathname'
require 'fileutils'

assets_template = Pathname(__FILE__).dirname + 'assets.example'
assets_config = Pathname(RAILS_ROOT) + 'config' + 'assets'

unless assets_config.exist?
  FileUtils.cp(assets_template, assets_config, :verbose => true)
  puts "Created assets file with default path of public/system"
end
