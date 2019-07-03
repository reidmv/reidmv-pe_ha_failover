#!/opt/puppetlabs/puppet/bin/ruby

require_relative "../../ruby_task_helper/files/task_helper.rb"
require 'open3'

class PausePuppetAgent < TaskHelper
  def task(duration:, **kwargs) 

    # Schedule the service to start back up later
    # Stop an existing timer if it exists
    system('systemctl status puppet.timer') && system('systemctl stop puppet.timer')
    output, status = Open3.capture2('systemd-run', "--on-active=#{duration}", '--unit', 'puppet.service')
    raise TaskHelper::Error.new('Failed to schedule re-enable action for Puppet agent',
                                'pe_ha_failover/task-error',
                                output) unless status.success?

    # Stop the service for now
    output, status = Open3.capture2e('systemctl', 'stop','puppet.service')
    raise TaskHelper::Error.new('Failed to pause Puppet agent',
                                'pe_ha_failover/task-error',
                                output) unless status.success?

    {}
  end
end

if __FILE__ == $0
  PausePuppetAgent.run
end
