class pe_ha_failover::temporary_pxp_conf::absent {
  file { '/etc/puppetlabs/pxp-agent/tmp':
    ensure => absent,
    force  => true,
  }

  service { 'pxp-agent-double':
    ensure => stopped,
  }
}
