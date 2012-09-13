module LogicalConstruct
  class UnpackCookbook < Mattock::TaskLib
    def default_namespace
      :cookbook
    end

    def default_settings(provision)
      settings(
        :construct_dir => provision.construct_dir,
        :cookbook_metadata => nil,
        :cookbook_dir => nil,
        :cookbook_name => "cookbook",
        :cookbook_archive => nil
      )
    end

    def resolve_settings
      self.cookbook_archive ||= File::join(construct_dir, "cookbook.tbz")
      self.cookbook_dir ||= File::join(construct_dir, cookbook_name)

      self.cookbook_metadata ||= File::join(cookbook_dir, "metadata.rb")
    end

    def untar_command
      Mattock::CommandLine.new("tar", "-xjf") do |cmd|
        cmd.options << cookbook_archive
      end
    end

    def define
      in_namespace do
        file cookbook_archive
        file cookbook_metadata => cookbook_archive do
          untar_command.run
        end
        task :unpack => cookbook_metadata
      end
    end
  end
end
