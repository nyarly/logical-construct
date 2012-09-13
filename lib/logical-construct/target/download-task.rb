module LogicalConstruct
  class DownloadTask < Mattock::FileCreationTask
    required_fields :source_uri, :destination_path

    def resolve_configuration
      self.task_name ||= destination_path
      super
    end

    def action
      require 'net/http'

      File::open(destination_path, "w") do |file|
        file.write(Net::HTTP::get(URI(source_uri)))
      end
    end
  end
end
