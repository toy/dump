case
when defined?(Rails::Generator::Base)
  # Generator for rails < 3
  class AssetsConfigGenerator < Rails::Generator::Base
    def manifest
      record do |m|
        m.file 'assets', 'config/assets'
      end
    end
  end
when defined?(Rails::Generators::Base)
  # Generator for rails >= 3
  class AssetsConfigGenerator < Rails::Generators::Base
    def create_assets_config
      create_file 'config/assets', File.read(File.join(File.dirname(__FILE__), 'templates/assets'))
    end
  end
end
