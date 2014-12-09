# encoding: UTF-8

require 'dump_rake'

module DumpRake
  # Helper for listing assets for dump
  module Assets
    SPLITTER = /[:,]/

    class << self
      def assets
        File.readlines(File.join(DumpRake::RailsRoot, 'config/assets')).map(&:strip).grep(/^[^#]/).join(':')
      end

      def glob_asset_children(asset, glob)
        path = File.expand_path(asset, DumpRake::RailsRoot)
        if path[0, DumpRake::RailsRoot.length] == DumpRake::RailsRoot # asset must be in rails root
          Dir[File.join(path, glob)]
        else
          []
        end
      end
    end
  end
end
