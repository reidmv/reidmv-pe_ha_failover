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
  String $key,
  String $certificate,
  String $config,
) {

  File {
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
    notify => Service['pxp-agent-double'],
  }

  file { '/etc/puppetlabs/pxp-agent/tmp':
    ensure => directory,
    mode   => '0755',
  }

  file { '/etc/puppetlabs/pxp-agent/tmp/certificate.pem':
    content => $certificate,
  }

  file { '/etc/puppetlabs/pxp-agent/tmp/key.pem':
    content => $key,
  }

  file { '/etc/puppetlabs/pxp-agent/tmp/ca.pem':
    source => '/etc/puppetlabs/puppet/ssl/certs/ca.pem',
  }

  file { '/etc/puppetlabs/pxp-agent/tmp/pxp-agent.conf':
    content => $config,
  }

  service { 'pxp-agent-double':
    ensure   => running,
    provider => systemd,
    start    => @(EOS/L),
      systemd-run --unit pxp-agent-double.service \
        /opt/puppetlabs/puppet/bin/pxp-agent \
          --foreground \
          --pidfile /var/run/puppetlabs/pxp-agent-double.pid \
          --config-file /etc/puppetlabs/pxp-agent/tmp/pxp-agent.conf
      |-EOS
  }

}
