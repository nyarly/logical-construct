#Outstanding issues:
#Where is the ephemeral storage mounted?  Probably needs to start as a config, maybe detect later
#
#Data required:
#Three categories: arbitrary (merely shared), task parameters, configuations
#
#From the EC2 user guide:
#
#[Provisioned]
#Upload EC2 credentials to ephemeral storage (i.e. pk.pem + cert.pem)
#[end provisioned]
#
#[Local to baked machine - should be in target rakefile]
#Write access needed on instance store (/mnt or /media/ephemeral0)
#[end local]
#
#So, if provision, needs to be something like:
#
#GC:
#rake bake[target,ami_name]
# -> ssh target rake bake (can return 13:"Target incapable", but if 0:...)
#    Important here - on success, there needs to be a long-running process on target
#    So: background self?  Fork new process and return "We're good to go?"
# -> build json configs
# -> ssh tunnel'd provision (target wants creds, configs)
# "Baking initialized"
#
#(Pattern to be repeated in remote re-provisioning, too)
#
#How to tell when done, where it's at?
#
#Target rake task needs to log process, so reviewing/tailing logs lets us answer
#the question "is it done yet." SNS/SES/other email when done?  Maybe something
#simple like "mail" command - if set up, bully, otherwise, you're on your own

require 'mattock/tasklib'
module LogicalConstruct
  module AWS
    class BakeSystem < Mattock::Tasklib
      include DirectoryStructure

      runtime_setting :ami_name, "image"

      #XXX Varies by bake - nascent -> set-up vs. set-up -> provisioned or
      #    provisioned -> provisioned
      runtime_setting :upload_bucket

      #Configurations:
      #(bundle options, like includes)

      setting :bundle_options, nested{
        setting :include_paths, %w{ /opt/ec2-ami-tools/etc/ec2/amitools/cert-ec2.pem /etc/ssl/* }
        setting :cpu_architecture, "x86_64"
        setting :kernel_id, "aki-88aa75e1"
        setting :ec2_region, "us-east-1"
      }

      dir(:ephemeral_mountpoint,
          dir(:bundle_workdir, "bundle_workdir",
               path(:bundle_manifest),
               path(:credentials_archive, "aws-creds.tar.gz"),
               dir(:credentials_dir, "aws-creds",
                    path(:private_key_file, "pk.pem"),
                    path(:certificate_file, "cert.pem")
                   )
              )
          )

      runtime_setting :s3_access_key
      runtime_setting :s3_secret_key
      runtime_setting :user_id

      def default_configuration(bake, resolution)
        self.bundle_manifest.relative_path = "#{ami_name}.img.manifest.xml"
      end

      def resolve_configuration
        resolve_paths
      end

      include Mattock::CommandLineDSL
      def define
        in_namespace do
          #CommandTask.new do |writable|
          #  writable.task_name = :ensure_store_writable
          #end

          #XXX Update AMI tools!
          #XXX Or use AMI SDK instead of command line?
          #CommandTask.new do |update_tools|
          #  update_tools.task_name = :update_ami_tools
          #end
          #
          #XXX Disable SELinux?
          #XXX Consider switching to "runlevel 1" or something like it
          #    (Although also that networking will be stopped

          CommandTask.new do |bundle|
            bundle.task_name = :bundle_volume
            bundle.command =
              cmd("ec2-bundle-vol",
                  "--privatekey #{private_key_file.absolute_path}",
                  "--cert #{certificate_file.absolute_path}",
                  "--user #{user_id}",
                  "--destination #{bundle_workdir.absolute_path}",
                  "--arch #{bundle_options.cpu_architecture}",
                  "--prefix #{ami_name}")
            bundle_options.include_paths.each do |path|
              bundle.command.options << "--include #{path}"
            end
          end

          CommandTask.new do |upload|
            upload.task_name = :upload_bundle
            upload.command =
              cmd("ec2-upload-bundle",
                  "--bucket #{upload_bucket}",
                  "--manifest #{bundle_manifest.absolute_path}",
                  "--access-key #{s3_access_key}",
                  "--secret-key #{s3_secret_key}",
                  "--retry")
          end
          task :upload_bundle => :bundle_volume

          CommandTask.new do |register|
            register.task_name = :register_ami
            register.command =
              cmd("ec2-register",
                  "--aws-access-key #{s3_access_key}",
                  "--aws-secret-key #{s3_secret_key}",
                  "--region #{bundle_settings.ec2_region}",
                  "#{upload_bucket}/#{ami_name}.img.manifest.xml",
                  "--name #{image_name}",
                  "--kernel #{bundle_settings.kernel_id}",
                  "--architecture #{bundle_options.cpu_architecture}")
          end
          task :register_ami => :upload_bundle

          task :run => [:bundle_volume, :upload_bundle, :register_ami]
        end
        task 'bake:run' => self[:run]
      end
    end
  end
end
