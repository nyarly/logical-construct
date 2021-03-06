module LogicalConstruct
  class UnpackPlan < Mattock::TaskLib
    dir(:current)
    dir(:live_temp)


    def default_namespace
      :unpack_plan
    end

    def default_configuration(provision)
      settings(
        :construct_dir => provision.construct_dir,
        :cookbook_metadata => nil,
        :cookbook_dir => nil,
        :cookbook_name => "cookbook",
        :cookbook_archive => nil
      )
    end

    def resolve_configuration
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
