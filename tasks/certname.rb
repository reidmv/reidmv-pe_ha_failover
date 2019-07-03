#!/opt/puppetlabs/puppet/bin/ruby

require_relative "../../ruby_task_helper/files/task_helper.rb"
require 'open3'

class Certname < TaskHelper
  def task(**kwargs) 
    output, status = Open3.capture2e('/opt/puppetlabs/bin/puppet', 'config',
                                     'print', 'certname', '--section', 'agent')

    raise TaskHelper::Error.new('Failed to determine Puppet certname',
                                'pe_ha_failover/task-error',
                                output) unless status == 0

    {
      certname: output.chomp,
    }
  end 
end

if __FILE__ == $0
  Certname.run
end
