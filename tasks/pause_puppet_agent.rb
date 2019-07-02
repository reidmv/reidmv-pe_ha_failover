#!/opt/puppetlabs/puppet/bin/ruby

require_relative "../../ruby_task_helper/files/task_helper.rb"
require 'open3'

class PausePuppetAgent < TaskHelper
  def task(duration:, **kwargs) 
    output, status = Open3.capture2e('/opt/puppetlabs/bin/puppet', 'agent','--disable', "Puppet agent runs paused for #{duration} by Bolt task")

    raise TaskHelper::Error.new('Failed to pause Puppet agent',
                                'pe_ha_failover/task-error',
                                output) unless status.success?

    lockfile = Open3.capture2('/opt/puppetlabs/bin/puppet', 'config', 'print', 'agent_disabled_lockfile', '--section', 'agent').first.chomp
    modified = Open3.capture2('stat', '-c%Y', lockfile).first.chomp

    output, status = Open3.capture2('systemd-run', "--on-active=#{duration}", 'bash', '-c', %Q{[ "$(stat -c%Y #{lockfile})" = "#{modified}" ] && rm "#{lockfile}"})

    raise TaskHelper::Error.new('Failed to schedule re-enable action for Puppet agent',
                                'pe_ha_failover/task-error',
                                output) unless status.success?

    {}
  end 
end

if __FILE__ == $0
  PausePuppetAgent.run
end
