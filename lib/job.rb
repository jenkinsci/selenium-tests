#!/usr/bin/env ruby
# vim: tabstop=2 expandtab shiftwidth=2

require File.dirname(__FILE__) + "/pageobject.rb"
require File.dirname(__FILE__) + "/build.rb"

module Jenkins
  class Job < PageObject
    attr_accessor :timeout

    def initialize(*args)
      @timeout = 60 # Default all builds for this job to a 60s timeout
      super(*args)
    end

    def job_url
      @base_url + "/job/#{@name}"
    end

    def configure_url
      job_url + "/configure"
    end

    def config_xml
       job_url + "/config.xml"
    end

    def configure(&block)
      visit configure_url
      unless block.nil?
        yield
        save
      end
    end

    def add_parameter(type,name,value)
      ensure_config_page
      find(:xpath, "//input[@name='parameterized']").set(true)
      find(:xpath, "//button[text()='Add Parameter']").click
      find(:xpath, "//a[text()='#{type}']").click
      find(:xpath, "//input[@name='parameter.name']").set(name)
      find(:xpath, "//input[@name='parameter.defaultValue']").set(value)
    end


    def add_shell_step(script)
      ensure_config_page

      find(:xpath, "//button[text()='Add build step']").locate.click
      find(:xpath, "//a[text()='Execute shell']").click
      find(:xpath, "//textarea[@name='command']").set(script)
    end

    def change_script_step(script)
      ensure_config_page

      # HACK: on a sufficiently busy configuration page, the "add build step" button can end up below
      # the sticky "save" button, and Chrome driver says that's not clickable. So we first scroll all
      # the way down, so that "add build step" will appear top of the page.
      page.execute_script "window.scrollTo(0, document.body.scrollHeight)"

      find(:xpath, "//textarea[@name='command']").set(script)
    end


    def add_postbuild_action(action)
      ensure_config_page

      find(:xpath, "//button[text()='Add post-build action']").locate.click
      find(:xpath, "//a[text()='#{action}']").click
    end

    def open
      visit(job_url)
    end

    def last_build
      return build("lastBuild") # Hacks!
    end

    def workspace
      Jenkins::Workspace.new(job_url)
    end

    def build(number)
      Jenkins::Build.new(@base_url, self, number)
    end

    def queue_build
      visit("#{job_url}/build?delay=0sec")
      # This is kind of silly, but I can't think of a better way to wait for the
      # build to complete
      sleep 5
    end

    def wait_for_build(number)
      build = self.build(number)
      start = Time.now
      while (build.in_progress? && ((Time.now - start) < @timeout))
        sleep 1
      end
    end

    def label_expression=(expression)
      ensure_config_page
      find(:xpath, "//input[@name='hasSlaveAffinity']").locate.set(true)
      find(:xpath, "//input[@name='_.assignedLabelString']").set(expression)
    end

    def disable
      check 'disable'
    end

    def archive_artifacts(options)
      case
      when options[:includes]
        add_postbuild_action "Archive the artifacts"
        find(:path, "/publisher/artifacts").set(options[:includes])
      when options[:excludes]
        find(:path, "/publisher/advanced-button").localte.click
        find(:path, "/publisher/excludes").set(options[:excludes])
      when options[:latestOnly]
        find(:path, "/publisher/advanced-button").locate.click
        find(:path, "/publisher/latestOnly").set(options[:latestOnly])
      end

    end

    def self.create_freestyle(base_url, name)
      visit("#{@base_url}/newJob")

      fill_in "name", :with => name
      find(:xpath, "//input[starts-with(@value, 'hudson.model.FreeStyleProject')]").set(true)
      click_button "OK"

      self.new(base_url, name)
    end

    def self.create_matrix(base_url, name)
      visit("#{@base_url}/newJob")

      fill_in "name", :with => name
      find(:xpath, "//input[starts-with(@value, 'hudson.matrix.MatrixProject')]").set(true)
      click_button "OK"

      self.new(base_url, name)
    end

    def self.copy_job(base_url, name, source_job_name)
      visit("#{@base_url}/newJob")
      fill_in "name", :with => name
      find(:xpath, "//input[@id='copy']").set(true)
      fill_in "from", :with => source_job_name
      click_button "OK"

      self.new(base_url, name)
    end
  end
end
