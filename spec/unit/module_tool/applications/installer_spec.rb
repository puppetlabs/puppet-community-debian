require 'spec_helper'
require 'puppet/module_tool/applications'
require 'puppet_spec/modules'
require 'semver'

describe Puppet::ModuleTool::Applications::Installer, :fails_on_windows => true do
  include PuppetSpec::Files

  before do
    FileUtils.mkdir_p(modpath1)
    fake_env.modulepath = [modpath1]
    FileUtils.touch(stdlib_pkg)
    Puppet.settings[:modulepath] = modpath1
    Puppet::Forge.stubs(:remote_dependency_info).returns(remote_dependency_info)
    Puppet::Forge.stubs(:repository).returns(repository)
  end

  let(:unpacker)        { stub(:run) }
  let(:installer_class) { Puppet::ModuleTool::Applications::Installer }
  let(:modpath1)        { File.join(tmpdir("installer"), "modpath1") }
  let(:stdlib_pkg)      { File.join(modpath1, "pmtacceptance-stdlib-0.0.1.tar.gz") }
  let(:fake_env)        { Puppet::Node::Environment.new('fake_env') }
  let(:options)         { Hash[:target_dir => modpath1] }

  let(:repository) do
    repository = mock()
    repository.stubs(:uri => 'forge-dev.puppetlabs.com')

    releases = remote_dependency_info.each_key do |mod|
      remote_dependency_info[mod].each do |release|
        repository.stubs(:retrieve).with(release['file'])\
                  .returns("/fake_cache#{release['file']}")
      end
    end

    repository
  end

  let(:remote_dependency_info) do
    {
      "pmtacceptance/stdlib" => [
        { "dependencies" => [],
          "version"      => "0.0.1",
          "file"         => "/pmtacceptance-stdlib-0.0.1.tar.gz" },
        { "dependencies" => [],
          "version"      => "0.0.2",
          "file"         => "/pmtacceptance-stdlib-0.0.2.tar.gz" },
        { "dependencies" => [],
          "version"      => "1.0.0",
          "file"         => "/pmtacceptance-stdlib-1.0.0.tar.gz" }
      ],
      "pmtacceptance/java" => [
        { "dependencies" => [["pmtacceptance/stdlib", ">= 0.0.1"]],
          "version"      => "1.7.0",
          "file"         => "/pmtacceptance-java-1.7.0.tar.gz" },
        { "dependencies" => [["pmtacceptance/stdlib", "1.0.0"]],
          "version"      => "1.7.1",
          "file"         => "/pmtacceptance-java-1.7.1.tar.gz" }
      ],
      "pmtacceptance/apollo" => [
        { "dependencies" => [
            ["pmtacceptance/java", "1.7.1"],
            ["pmtacceptance/stdlib", "0.0.1"]
          ],
          "version" => "0.0.1",
          "file"    => "/pmtacceptance-apollo-0.0.1.tar.gz" },
        { "dependencies" => [
            ["pmtacceptance/java", ">= 1.7.0"],
            ["pmtacceptance/stdlib", ">= 1.0.0"]
          ],
          "version" => "0.0.2",
          "file"    => "/pmtacceptance-apollo-0.0.2.tar.gz" }
      ]
    }
  end

  describe "the behavior of .is_module_package?" do
    it "should return true when file is a module package" do
      pending("porting to Windows", :if => Puppet.features.microsoft_windows?) do
        installer = installer_class.new("foo", options)
        installer.send(:is_module_package?, stdlib_pkg).should be_true
      end
    end

    it "should return false when file is not a module package" do
      pending("porting to Windows", :if => Puppet.features.microsoft_windows?) do
        installer = installer_class.new("foo", options)
        installer.send(:is_module_package?, "pmtacceptance-apollo-0.0.2.tar").
          should be_false
      end
    end
  end

  context "when the source is a repository" do
    it "should require a valid name" do
      lambda { installer_class.run('puppet', params) }.should
        raise_error(ArgumentError, "Could not install module with invalid name: puppet")
    end

    it "should install the requested module" do
      pending("porting to Windows", :if => Puppet.features.microsoft_windows?) do
        Puppet::ModuleTool::Applications::Unpacker.expects(:new).
          with('/fake_cache/pmtacceptance-stdlib-1.0.0.tar.gz', options).
          returns(unpacker)
        results = installer_class.run('pmtacceptance-stdlib', options)
        results[:installed_modules].length == 1
        results[:installed_modules][0][:module].should == "pmtacceptance-stdlib"
        results[:installed_modules][0][:version][:vstring].should == "1.0.0"
      end
    end

    context "when the requested module has dependencies" do
      it "should install dependencies" do
        pending("porting to Windows", :if => Puppet.features.microsoft_windows?) do
          Puppet::ModuleTool::Applications::Unpacker.expects(:new).
            with('/fake_cache/pmtacceptance-stdlib-1.0.0.tar.gz', options).
            returns(unpacker)
          Puppet::ModuleTool::Applications::Unpacker.expects(:new).
            with('/fake_cache/pmtacceptance-apollo-0.0.2.tar.gz', options).
            returns(unpacker)
          Puppet::ModuleTool::Applications::Unpacker.expects(:new).
            with('/fake_cache/pmtacceptance-java-1.7.1.tar.gz', options).
            returns(unpacker)

          results = installer_class.run('pmtacceptance-apollo', options)
          installed_dependencies = results[:installed_modules][0][:dependencies]

          dependencies = installed_dependencies.inject({}) do |result, dep|
            result[dep[:module]] = dep[:version][:vstring]
            result
          end

          dependencies.length.should == 2
          dependencies['pmtacceptance-java'].should   == '1.7.1'
          dependencies['pmtacceptance-stdlib'].should == '1.0.0'
        end
      end

      it "should install requested module if the '--force' flag is used" do
        pending("porting to Windows", :if => Puppet.features.microsoft_windows?) do
          options = { :force => true, :target_dir => modpath1 }
          Puppet::ModuleTool::Applications::Unpacker.expects(:new).
            with('/fake_cache/pmtacceptance-apollo-0.0.2.tar.gz', options).
            returns(unpacker)
          results = installer_class.run('pmtacceptance-apollo', options)
          results[:installed_modules][0][:module].should == "pmtacceptance-apollo"
        end
      end

      it "should not install dependencies if the '--force' flag is used" do
        pending("porting to Windows", :if => Puppet.features.microsoft_windows?) do
          options = { :force => true, :target_dir => modpath1 }
          Puppet::ModuleTool::Applications::Unpacker.expects(:new).
            with('/fake_cache/pmtacceptance-apollo-0.0.2.tar.gz', options).
            returns(unpacker)
          results = installer_class.run('pmtacceptance-apollo', options)
          dependencies = results[:installed_modules][0][:dependencies]
          dependencies.should == []
        end
      end

      it "should not install dependencies if the '--ignore-dependencies' flag is used" do
        pending("porting to Windows", :if => Puppet.features.microsoft_windows?) do
          options = { :ignore_dependencies => true, :target_dir => modpath1 }
          Puppet::ModuleTool::Applications::Unpacker.expects(:new).
            with('/fake_cache/pmtacceptance-apollo-0.0.2.tar.gz', options).
            returns(unpacker)
          results = installer_class.run('pmtacceptance-apollo', options)
          dependencies = results[:installed_modules][0][:dependencies]
          dependencies.should == []
        end
      end

      it "should set an error if dependencies can't be resolved" do
        pending("porting to Windows", :if => Puppet.features.microsoft_windows?) do
          options = { :version => '0.0.1', :target_dir => modpath1 }
          oneline = "'pmtacceptance-apollo' (v0.0.1) requested; Invalid dependency cycle"
          multiline = <<-MSG.strip
Could not install module 'pmtacceptance-apollo' (v0.0.1)
  No version of 'pmtacceptance-stdlib' will satisfy dependencies
    You specified 'pmtacceptance-apollo' (v0.0.1),
    which depends on 'pmtacceptance-java' (v1.7.1),
    which depends on 'pmtacceptance-stdlib' (v1.0.0)
    Use `puppet module install --force` to install this module anyway
MSG

          results = installer_class.run('pmtacceptance-apollo', options)
          results[:result].should == :failure
          results[:error][:oneline].should == oneline
          results[:error][:multiline].should == multiline
        end
      end
    end

    context "when there are modules installed" do
      it "should use local version when already exists and satisfies constraints"
      it "should reinstall the local version if force is used"
      it "should upgrade local version when necessary to satisfy constraints"
      it "should error when a local version can't be upgraded to satisfy constraints"
    end

    context "when a local module needs upgrading to satisfy constraints but has changes" do
      it "should error"
      it "should warn and continue if force is used"
    end

    it "should error when a local version of a dependency has no version metadata"
    it "should error when a local version of a dependency has a non-semver version"
    it "should error when a local version of a dependency has a different forge name"
    it "should error when a local version of a dependency has no metadata"
  end

  context "when the source is a filesystem" do
    before do
      @sourcedir = tmpdir('sourcedir')
    end

    it "should error if it can't parse the name"

    it "should try to get_release_package_from_filesystem if it has a valid name"
  end
end
