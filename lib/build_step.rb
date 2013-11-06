require File.dirname(__FILE__) + "/step.rb"

module Jenkins
  class BuildStep
    include Jenkins::Step

    def self.add(job, title)

      find(:path, '/hetero-list-add[builder]').locate.click
      click_link label(title)

      sleep 1
      prefix = all(:xpath, "//div[@name='builder']").last[:path]

      return type(title).new(job, prefix)
    end

    @@types = Hash.new

    def self.register(title, label)
      raise "#{title} already registered" if @@types.has_key? title

      @@types[title] = {type: self, label: label}
    end

    def self.get(title)
      return @@types[title] if @@types.has_key? title

      raise "Unknown #{self.name.split('::').last} type #{title}. #{@@types.keys}"
    end
  end

  class ShellBuildStep < BuildStep

    register 'Shell', 'Execute shell'

    def command(text)
      control('command').locate.set(text)
    end
  end
end
