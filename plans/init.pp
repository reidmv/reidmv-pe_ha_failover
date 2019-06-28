plan pe_ha_failover (
  String $master,
  String $replica,
) {
  # Set up targets for reaching the endpoints we need to over the transports we
  # want to, as appropriate
  Target.new($master,               name => 'master1_pcp1').add_to_group('pe_ha_failover_pcp1')
  Target.new($master,               name => 'master1_pcp2').add_to_group('pe_ha_failover_pcp2')
  Target.new("${master}-pseudonym", name => 'master1_pcp2_pseudonym').add_to_group('pe_ha_failover_pcp2')
  Target.new($replica,              name => 'master2_pcp1').add_to_group('pe_ha_failover_pcp1')
  Target.new($replica,              name => 'master2_pcp2').add_to_group('pe_ha_failover_pcp2')
  Target.new("local://${replica}",  name => 'master2_local').add_to_group('all')

  # Check to see if the original master is connected
  $master1_pcp1_connected = wait_until_available('master1_pcp1',
    wait_time       => 0,
    _catch_errors   => true,
  ).ok

  # How do we / should we connect to master1 after replica promotion?
  $master1_postpromote = $master1_pcp1_connected ? {
    true  => "${master}-pseudonym",
    false => [ ],
  }

  if $master1_pcp1_connected {
    # Sanity sync some important content
    $hierayaml = run_task('pe_ha_failover::read_file', 'master1_pcp1',
      path => '/etc/puppetlabs/puppet/hiera.yaml',
    ).first['content']

    run_task('pe_ha_failover::write_file', 'master2_local',
      path    => '/etc/puppetlabs/puppet/hiera.yaml',
      content => $hierayaml,
    )

    # Change out the certificate in use by master1. This is because during the
    # promotion process, the master's normal cert will be revoked, rendering it
    # unable to connect to the orchestrator.
    $certdata = run_task('pe_ha_failover::generate_certificate', 'master1_pcp1',
      certname => $master1_postpromote,
    ).first.value

    # Apply temporary pxp-agent config to ensure connectivity is retained
    # throughout agent re-cert process
    $master1_orig_pxp_config = run_task('pe_ha_failover::read_file', 'master1_pcp1',
      path => '/etc/puppetlabs/pxp-agent/pxp-agent.conf',
    ).first['content'].parsejson
    $master1_new_pxp_config = $master1_orig_pxp_config + {
      # 'broker-ws-uris' => $master1_orig_pxp_config['broker-ws-uris'].reverse_each,
      # 'master-uris'    => $master1_orig_pxp_config['master-uris'].reverse_each,
      'ssl-ca-cert'    => '/etc/puppetlabs/pxp-agent/tmp/ca.pem',
      'ssl-cert'       => '/etc/puppetlabs/pxp-agent/tmp/certificate.pem',
      'ssl-key'        => '/etc/puppetlabs/pxp-agent/tmp/key.pem',
    }

    apply('master1_pcp1') {
      class { 'pe_ha_failover::temporary_pxp_conf':
        key         => $certdata['key'],
        certificate => $certdata['certificate'],
        config      => $master1_new_pxp_config.to_json,
      }
    }

    wait_until_available($master1_postpromote,
      wait_time => 10,
    )

    # This will "fail" because it will shut down the orchestrator service used
    # to connect to the target
    run_task('enterprise_tasks::disable_all_puppet_services', $master1_postpromote,
      _catch_errors => true,
    )
  }

  # Promote the replica
  run_command(@("EOS"/L), 'master2_local')
    /opt/puppetlabs/bin/puppet infra promote replica \
    --topology mono-with-compile \
    --classifier-termini ${replica}:4433 \
    --puppetdb-termini ${replica}:8081 \
    --infra-agent-server-urls ${replica}:8140 \
    --infra-pcp-brokers ${replica}:8142 \
    --agent-server-urls ${replica}:8140 \
    --pcp-brokers ${replica}:8142 \
    --skip-agent-config \
    --yes
    |-EOS

  # Ensure both masters are connected
  wait_until_available(['master1_pcp2', 'master2_pcp2'],
    wait_time     => 180,
    _catch_errors => true,
  )

  # Restore the old master as the new replica
  run_plan('enterprise_tasks::enable_ha_failover',
    host              => 'master1_pcp2',
    caserver          => 'master2_local',
    topology          => 'mono-with-compile',
    skip_agent_config => true,
  )

  run_command('rm -rf /etc/puppetlabs/pxp-agent/tmp', 'master1_pcp2')

  return('plan complete')
}
