module Dump
  class Reader < Snapshot
    # Helper class for reading assets
    class Assets
      attr_reader :dump
      delegate :config, :to => :dump

      def initialize(dump)
        @dump = dump
      end

      def read
        return if Dump::Env[:restore_assets] && Dump::Env[:restore_assets].empty?
        return if config[:assets].blank?

        assets = config[:assets]
        if assets.is_a?(Hash)
          assets_count = assets.values.sum{ |value| value.is_a?(Hash) ? value[:total] : value }
          assets_paths = assets.keys
        else
          assets_count, assets_paths = nil, assets
        end

        if Dump::Env[:restore_assets]
          assets_paths.each do |asset|
            Dump::Assets.glob_asset_children(asset, '**/*').reverse.each do |child|
              next unless read_asset?(child, Dump.rails_root)
              case
              when File.file?(child)
                File.unlink(child)
              when File.directory?(child)
                begin
                  Dir.unlink(child)
                rescue Errno::ENOTEMPTY
                  nil
                end
              end
            end
          end
        else
          Dump::Env.with_env(:assets => assets_paths.join(':')) do
            Rake::Task['assets:delete'].invoke
          end
        end

        read_assets_entries(assets_paths, assets_count) do |stream, root, entry, prefix|
          if !Dump::Env[:restore_assets] || read_asset?(entry.full_name, prefix)
            stream.extract_entry(root, entry)
          end
        end
      end

      def read_assets_entries(_assets_paths, assets_count)
        Progress.start('Assets', assets_count || 1) do
          found_assets = false
          # old style - in separate tar
          dump.find_entry('assets.tar') do |assets_tar|
            def assets_tar.rewind
              # rewind will fail - it must go to center of gzip
              # also we don't need it - this is last step in dump restore
            end
            Archive::Tar::Minitar.open(assets_tar) do |inp|
              inp.each do |entry|
                yield inp, Dump.rails_root, entry, nil
                Progress.step if assets_count
              end
            end
            found_assets = true
          end

          unless found_assets
            # new style - in same tar
            dump.send :assets_root_link do |tmpdir, prefix|
              dump.stream.each do |entry|
                if entry.full_name.starts_with?("#{prefix}/")
                  yield dump.stream, tmpdir, entry, prefix
                  Progress.step if assets_count
                end
              end
            end
          end
        end
      end

      def read_asset?(path, prefix)
        Dump::Env.filter(:restore_assets, Dump::Assets::SPLITTER).custom_pass? do |value|
          File.fnmatch(File.join(prefix, value), path) ||
            File.fnmatch(File.join(prefix, value, '**'), path)
        end
      end
    end
  end
end
