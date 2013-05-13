#!/usr/bin/env ruby
# vim: tabstop=2 expandtab shiftwidth=2


Given /^a simple job$/ do
  @job = Jenkins::Job.create_freestyle(@base_url, Jenkins::Job.random_name)
  @job.configure do
    @job.add_shell_step("ls")
  end
end

Given /^a job$/ do
  @job = Jenkins::Job.create_freestyle(@base_url, Jenkins::Job.random_name)
end


When /^I create a job named "([^"]*)"$/ do |name|
  @job = Jenkins::Job.create_freestyle(@base_url, name)
end

When /^I copy the job named "([^"]*)" from job named "([^"]*)"$/ do |name, source_job_name|
  @job = Jenkins::Job.copy_job(@base_url, name, source_job_name)
end

When /^I build the job$/ do
  @job.queue_build
end

When /^I save the job$/ do
  @job.save
end

When /^I visit the job page$/ do
  @job.open
end

When /^I visit (job|build) action named "([^"]*)"$/ do |entity, action|
  page_object = entity == 'job' ? @job : @job.last_build.wait_until_finished
  page_object.open
  find(:xpath, "//div[@id='tasks']/div/a[text()='#{action}']").click
end

When /^I build (\d+) jobs$/  do |count|
  count.to_i.times do |i|
    @job.queue_build
  end
end

When /^I build (\d+) jobs sequentially$/  do |count|
  count.to_i.times do |i|
    @job.queue_build
    sleep 0.5 # Wait for newly queued build to become the last build
    @job.last_build.wait_until_finished
  end
end

Then /^I should see console output matching "(.*)"$/ do |script|
  build = @job.last_build.wait_until_finished
  build.console.should match /#{Regexp.escape(script)}/
end

Then /^I should see console output matching regexp "(.*)"$/ do |script|
  build = @job.last_build.wait_until_finished
  build.console.should match /#{script}/
end

Then /^the (job|build) (should|should not) have "([^"]*)" action$/ do |entity, should_or_not, action|
  page_object = entity == 'job' ? @job : @job.last_build.wait_until_finished
  page_object.open
  page.send should_or_not, have_xpath("//div[@id='tasks']/div/a[text()='#{action}']")
end

Then /^the (\d+) jobs should run concurrently$/ do |count|
  # Wait until all jobs have started
  count.to_i.times do |i|
    @job.build(i + 1).wait_until_started
  end

  # then all jobs should be in progress at the same time
  count.to_i.times do |i|
    @job.build(i + 1).in_progress?.should be true
  end
end

Then /^I should be prompted to enter the "(.*?)" parameter$/ do |param_name|
  find(:xpath, "//input[@value='#{param_name}']").instance_of?(Capybara::Node::Element).should be true
end

Then /^the build should (succeed|fail)$/ do |status|
  expected = status == 'succeed'
  @job.last_build.succeeded?.should eql(expected), "\nConsole output:\n#{@job.last_build.console}\n\n"
end

Then /^the build should be unstable$/ do
  @job.last_build.unstable?.should be true
end

Then /^it should be disabled$/ do
  page.should_not have_content 'Build Now'
end

Then /^it should have an "(.*?)" button on the job page$/ do |button|
  @job.open
  page.should have_xpath("//button[text()='#{button}']")
end

Then /^the job configuration should be equals to "([^"]*)" configuration$/ do |source_name|
  visit @job.config_xml
  source_page = page.html
  visit @base_url + "/job/#{source_name}/config.xml"
  (page.html.eql? source_page).should be true
end

Then /^the artifact "([^"]*)" (should|should not) be archived$/ do |artifact, should_or_not|
  @job.last_build.wait_until_finished.open
  page.send should_or_not, have_xpath("//a[@href='artifact/#{artifact}']")
end

Then /^the build #(\d+) (should|should not) have archived "([^"]*)" artifact$/ do |number, should_or_not, artifact|
  @job.build(number).wait_until_finished.open
  page.send should_or_not, have_xpath("//a[@href='artifact/#{artifact}']")
end

Then /^the content of artifact "([^"]*)" should be "([^"]*)"$/ do |artifact, content|
  visit @job.last_build.artifact_url(artifact)
  page.should have_content content
end

Then /^the size of artifact "([^"]*)" should be "([^"]*)"$/ do |artifact, size|
  @job.last_build.open
  actual = "//a[text()='#{artifact}']/../../td[@class='fileSize']"
  match = actual + "[text()='#{size}']"
  page.should have_xpath(match), 'Actual size: ' + find(:xpath, actual).text
end

Then /^the job should have description "([^"]*)"$/ do |description|
  @job.open
  desc = find(:xpath,'//div[@id="description"]/div')
  desc.should have_content(description)
end
