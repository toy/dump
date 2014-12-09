# encoding: UTF-8

require 'dump'

module Dump
  # Helper for listing assets for dump
  module Assets
    SPLITTER = /[:,]/

    class << self
      def assets
        File.readlines(File.join(Dump.rails_root, 'config/assets')).map(&:strip).grep(/^[^#]/).join(':')
      end

      def glob_asset_children(asset, glob)
        path = File.expand_path(asset, Dump.rails_root)
        if path[0, Dump.rails_root.length] == Dump.rails_root # asset must be in rails root
          Dir[File.join(path, glob)]
        else
          []
        end
      end
    end
  end
end
