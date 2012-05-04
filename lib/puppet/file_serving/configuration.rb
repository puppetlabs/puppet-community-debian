require 'monitor'
require 'puppet'
require 'puppet/file_serving'
require 'puppet/file_serving/mount'
require 'puppet/file_serving/mount/file'
require 'puppet/file_serving/mount/modules'
require 'puppet/file_serving/mount/plugins'

class Puppet::FileServing::Configuration
  require 'puppet/file_serving/configuration/parser'

  extend MonitorMixin

  def self.configuration
    synchronize do
      @configuration ||= new
    end
  end

  Mount = Puppet::FileServing::Mount

  private_class_method  :new

  attr_reader :mounts
  #private :mounts

  # Find the right mount.  Does some shenanigans to support old-style module
  # mounts.
  def find_mount(mount_name, environment)
    # Reparse the configuration if necessary.
    readconfig

    if mount = mounts[mount_name]
      return mount
    end

    if environment.module(mount_name)
      Puppet.deprecation_warning "DEPRECATION NOTICE: Files found in modules without specifying 'modules' in file path will be deprecated in the next major release.  Please fix module '#{mount_name}' when no 0.24.x clients are present"
      return mounts["modules"]
    end

    # This can be nil.
    mounts[mount_name]
  end

  def initialize
    @mounts = {}
    @config_file = nil

    # We don't check to see if the file is modified the first time,
    # because we always want to parse at first.
    readconfig(false)
  end

  # Is a given mount available?
  def mounted?(name)
    @mounts.include?(name)
  end

  # Split the path into the separate mount point and path.
  def split_path(request)
    # Reparse the configuration if necessary.
    readconfig

    mount_name, path = request.key.split(File::Separator, 2)

    raise(ArgumentError, "Cannot find file: Invalid path '#{mount_name}'") unless mount_name =~ %r{^[-\w]+$}

    return nil unless mount = find_mount(mount_name, request.environment)
    if mount.name == "modules" and mount_name != "modules"
      # yay backward-compatibility
      path = "#{mount_name}/#{path}"
    end

    if path == ""
      path = nil
    elsif path
      # Remove any double slashes that might have occurred
      path = path.gsub(/\/+/, "/")
    end

    return mount, path
  end

  def umount(name)
    @mounts.delete(name) if @mounts.include? name
  end

  private

  def mk_default_mounts
    @mounts["modules"] ||= Mount::Modules.new("modules")
    @mounts["modules"].allow('*') if @mounts["modules"].empty?
    @mounts["plugins"] ||= Mount::Plugins.new("plugins")
    @mounts["plugins"].allow('*') if @mounts["plugins"].empty?
  end

  # Read the configuration file.
  def readconfig(check = true)
    config = Puppet[:fileserverconfig]

    return unless FileTest.exists?(config)

    @parser ||= Puppet::FileServing::Configuration::Parser.new(config)

    return if check and ! @parser.changed?

    # Don't assign the mounts hash until we're sure the parsing succeeded.
    begin
      newmounts = @parser.parse
      @mounts = newmounts
    rescue => detail
      Puppet.log_exception(detail, "Error parsing fileserver configuration: #{detail}; using old configuration")
    end

  ensure
    # Make sure we've got our plugins and modules.
    mk_default_mounts
  end
end
