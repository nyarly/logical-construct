module LogicalConstruct
  class SetupRemoteTask < RemoteCommandTask
    def default_configuration(setup)
      super()
      @remote_server = setup.remote_server
    end
  end
end
