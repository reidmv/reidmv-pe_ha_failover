# @summary
#   Temporarily configures pxp-agent with a copy of its certificate
#   credentials. Intended to be used as an apply() block in a Bolt
#   plan.
#
# @param certname
#   The certname to use when making a copy of certificate credentials
# @param config
#   The JSON string config data to write to pxp-agent.conf
#
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
    source => '/etc/puppetlabs/puppet/ssl/certs/ca.pem',
  }

  file { '/etc/puppetlabs/pxp-agent/pxp-agent.conf':
    content => $config,
  }

  service { 'pxp-agent':
    ensure => running,
  }

}
