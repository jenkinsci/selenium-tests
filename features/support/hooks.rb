#!/usr/bin/env ruby
# vim: tabstop=2 expandtab shiftwidth=2

$LOAD_PATH.push File.dirname(__FILE__) + "/../.."
require "lib/controller/jenkins_controller.rb"
require "lib/controller/local_controller.rb"
require "lib/controller/sysv_init_controller.rb"
require "lib/controller/tomcat_controller.rb"
require "lib/controller/jboss_controller.rb"

Before('@realupdatecenter') do |scenario|
  @controller_options = {:real_update_center => true}
end

Before do |scenario|
  # default is to run locally, but allow the parameters to be given as env vars
  # so that rake can be invoked like "rake test type=remote_sysv"
  if ENV['type']
    controller_args = {}
    ENV.each { |k,v| controller_args[k.to_sym]=v }
  else
    controller_args = { :type => :local }
  end

  if @controller_options
    controller_args = controller_args.merge(@controller_options)
  end
  @runner = JenkinsController.create(controller_args)
  @runner.start
  at_exit do
    @runner.stop
    @runner.teardown
  end
  @base_url = @runner.url
  Capybara.app_host = @base_url

  # wait for Jenkins to properly boot up and finish initialization
  s = Capybara.current_session
  for i in 1..20 do
    begin
      s.visit "/systemInfo"
      s.find "TABLE.bigtable"
      break # found it
    rescue => e
      sleep 0.5
    end
  end
  
  # install form-element-path plugin if it's not pre-installed
  unless @runner.is_form_path_installed
    if( (defined? @runner.real_update_center) && !@runner.real_update_center )
      raise "Form-element-path plugin not pre-installed and update center is disabled. Tests need Form-element-path plugin, please ensure that plugin is installed."
    end
    manager = Jenkins::PluginManager.new(@base_url, nil)
    manager.install_plugin "form-element-path"
    found = @runner.log_watcher.wait_until_logged(/Installation successful: Form Element Path Plugin/i)
    raise "Cannot install form-element-path plugin" unless found
  end
end

After do |scenario|
  @runner.stop # if test fails, stop in at_exit is not called
end
