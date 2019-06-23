class pe_ha_failover::temporary_pxp_conf (
  String $certname,
  String $config,
) {

  File {
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
    notify => Service['pxp-agent'],
  }

  file { '/etc/puppetlabs/pxp-agent/tmp':
    ensure => directory,
    mode   => '0755',
  }

  file { '/etc/puppetlabs/pxp-agent/tmp/certificate.pem':
    source => "/etc/puppetlabs/puppet/ssl/certs/${certname}.pem",
  }

  file { '/etc/puppetlabs/pxp-agent/tmp/key.pem':
    source => "/etc/puppetlabs/puppet/ssl/private_keys/${certname}.pem",
  }

  file { '/etc/puppetlabs/pxp-agent/tmp/ca.pem':
    source => "/etc/puppetlabs/puppet/ssl/certs/ca.pem",
  }

  file { '/etc/puppetlabs/pxp-agent/pxp-agent.conf':
    content => $config,
  }

  service { 'pxp-agent':
    ensure => running,
  }

}
