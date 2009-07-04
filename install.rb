require 'pathname'

assets_template = Pathname(__FILE__) + 'assets.example'
assets_config = Pathname(RAILS_ROOT) + 'config' + 'assets'

unless assets_config.exists?
  File.copy(assets_template, assets_config, true)
  puts "Created blank assets file"
end
