require 'fileutils'

assets_template = File.join(File.dirname(__FILE__), 'assets.example')
assets_config = File.join(RAILS_ROOT, 'config', 'assets')

unless File.exists?(assets_config)
  FileUtils.copy_file(assets_template, assets_config)
  puts "Created blank assets file"
end
