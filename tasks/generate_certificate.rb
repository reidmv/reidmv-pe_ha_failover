#!/opt/puppetlabs/puppet/bin/ruby

require_relative "../../ruby_task_helper/files/task_helper.rb"
require 'open3'

class GenerateCertificate < TaskHelper
  def task(certname: nil, **kwargs) 
    output, status = Open3.capture2e('/opt/puppetlabs/bin/puppetserver', 'ca',
                                     'generate', '--certname', certname)

    raise TaskHelper::Error.new('Failed to generate a new certificate',
                                'pe_ha_failover/task-error',
                                output) unless status == 0

    {
      certificate: File.read("/etc/puppetlabs/puppet/ssl/certs/#{certname}.pem"),
      key: File.read("/etc/puppetlabs/puppet/ssl/private_keys/#{certname}.pem"),
    }
  end 
end

if __FILE__ == $0
  GenerateCertificate.run
end
