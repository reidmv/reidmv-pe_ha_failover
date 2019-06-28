class pe_ha_failover::ruby_task_helper {

  $dirs = [
    '/opt/puppetlabs/pxp-agent/ruby_task_helper',
    '/opt/puppetlabs/pxp-agent/ruby_task_helper/files',
  ]

  file { $dirs:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  file { '/opt/puppetlabs/pxp-agent/ruby_task_helper/files/task_helper.rb':
    ensure   => 'file',
    source   => 'puppet:///modules/ruby_task_helper/task_helper.rb',
    owner    => 'root',
    group    => 'root',
    mode     => '0640',
  }

}
