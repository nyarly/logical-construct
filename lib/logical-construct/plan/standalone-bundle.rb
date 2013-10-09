require 'mattock'
require 'mattock/bundle-command-task'

module LogicalConstruct
  module Plan
    class StandaloneBundle < Mattock::TaskLib
      include Mattock::CommandLineDSL
      default_namespace :bundler

      dir(:target_dir,
          path(:gemfile, "Gemfile"),
          dir(:gems, "gems"))

      def default_configuration(core)
        super
        target_dir.absolute_path = core.absolute_path
      end

      def resolve_configuration
        resolve_paths
        super
      end

      def define
        directory gems.absolute_path

        in_namespace do
          #bundler unconditionally re-produces bundle/setup.rb, which means
          #that plans that use this tasklib will always be re-packed, even when
          #the contents haven't changed significantly.
          #
          #It's possible that a "hash difference" file task could be written
          #for setup.rb? Kind of a hack. Or else tell bundler that it's config
          #dir goes in a temp directory, and then we move things, or local
          #rsync --checksum or something.
          Mattock::BundleCommandTask.define_task(:standalone => gems.absolute_path) do |bundle_build|
            bundle_build.command = (
              cmd("cd", target_dir.absolute_path) &
              cmd("bundle", "install"){|bundler|
              bundler.options << "--gemfile=" + gemfile.absolute_path
              bundler.options << "--path=" + gems.absolute_path
              bundler.options << "--standalone"
              bundler.options << "--binstubs=bin"
            })
          end

          task :pristine => gems.absolute_path do
            gem_scope = [Gem.ruby_engine, Gem::ConfigMap[:ruby_version]].join("/")

            cmd_env = {
              "RUBYOPT" => "",
              "GEM_HOME" => gems.pathname.join(gem_scope).to_s #XXX update this to use gem_scope from flight-deck
            }

            cmd("gem pristine") do |gem|
              gem.options << "--all"
              gem.options << "--extensions"
              gem.command_environment.merge! cmd_env
            end.must_succeed!
          end

          task :load_setup do
            require gems.pathname.join("bundler/setup")
          end
        end

        task 'install:perform' => self[:pristine]
        task 'compile:perform' => self[:standalone]
        task 'compile:preflight' => gemfile.absolute_path
        task :preflight => self[:load_setup]
      end
    end
  end
end
