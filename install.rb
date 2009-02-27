require 'fileutils'

assets_template = File.join(File.dirname(__FILE__), 'assets')
assets_config = 'config/assets'

unless File.exists?(assets_config)
  puts "Created blank assets file"
  FileUtils.cp(assets_template, assets_config)
end
