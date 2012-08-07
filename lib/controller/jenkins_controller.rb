require 'temp_dir'

# This module defines a contract that various Jenkins controller implementations need to support
#
# JenkinsController encapsulates a Jenkins installation, the subject of the test.
# It maybe a lone bare +jenkins.war+, it may be an installation of Jenkins on Tomcat,
# or it maybe a debian package installation of Jenkins that starts/stops via SysV init script.
# Jenkins may or may not be running on a local machine, etc.
#
# Each JenkinsController goes through the call sequence of +(start,restart*,stop)+ sprinkled with
# calls to +url+ and +diagnose+.
class JenkinsController
  attr_accessor :is_running, :log_watcher, :is_form_path_installed

  def initialize(*args)
    @is_running = false
    @log_watcher = nil
    @is_form_path_installed = false
  end

  # Starts Jenkins, with a brand new temporary JENKINS_HOME.
  #
  # This method can return as soon as the server becomes accessible via HTTP,
  # and it is the caller's responsibility to wait until Jenkins finishes its bootup sequence.
  def start!
    raise NotImplementedException
  end

  def start
    start! unless is_running?
    @is_running = true
  end

  # Restarts Jenkins
  def restart
    stop
    start
  end

  # Shuts down the Jenkins process.
  def stop!
    raise NotImplementedException
  end

  def stop
    stop! if is_running?
    @is_running = false
  end

  # return the URL where Jenkins is running, such as "http://localhost:9999/"
  # the URL must ends with '/'
  def url
    raise "Not implemented yet"
  end

  # local file path to obtain slave.jar
  # TODO: change this to URL.
  def slave_jar_path
    "#{@tempdir}/war/WEB-INF/slave.jar"
  end

  # called when a test failed. Produce diagnostic output to the console, to the extent you can,
  # such as printing out the server log, etc.
  def diagnose
    # default is no-op
  end

  # called at the very end to dispose any resources
  def teardown

  end

  def is_running?
    @is_running
  end

  def preinstall_form_path_plugin
    if( (defined? @form_path_hpi) && File.exists?(@form_path_hpi) )
      FileUtils.mkdir "#{@tempdir}/plugins" unless File.directory?("#{@tempdir}/plugins") 
      FileUtils.cp(@form_path_hpi,"#{@tempdir}/plugins")
      @is_form_path_installed = true
    else
      puts "Cannot pre-install form-element-path.hpi file, #{@form_path_hpi} doesn't exists or is not a file. Will try to install it from Update Center"
    end
  end


  # registered implementations
  @@impls = {}

  def self.create(args)
    t = @@impls[args[:type].to_sym]
    raise "Undefined controller type #{args[:type]}" if t.nil?
    t.new(args)
  end

  def self.register(type)
    @@impls[type] = self
  end
end
