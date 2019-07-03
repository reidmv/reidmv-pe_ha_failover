plan pe_ha_failover (
  TargetSpec $master,
  TargetSpec $replica,
) {
  $spec1 = get_targets($master)
  $spec2 = get_targets($replica)

  assert_type(Array[Target, 1, 1], $spec1) |$_, $actual| {
    out::message("Expected master to be a single target; got ${actual.map |$t| {$t.name}}") }
  assert_type(Array[Target, 1, 1], $spec2) |$_, $actual| {
    out::message("Expected replica to be a single target; got ${actual.map |$t| {$t.name}}") }

  $master1 = $spec1[0].host
  $master2 = $spec2[0].host

  # Set up targets for reaching the endpoints we need to over the transports we
  # want to, as appropriate
  Target.new($master1,             name => 'master1_pcp1').add_to_group('pe_ha_failover_pcp1')
  Target.new($master1,             name => 'master1_pcp2').add_to_group('pe_ha_failover_pcp2')
  Target.new("${master1}-double",  name => 'master1_double_pcp1').add_to_group('pe_ha_failover_pcp1')
  Target.new("${master1}-double",  name => 'master1_double_pcp2').add_to_group('pe_ha_failover_pcp2')
  Target.new($master2,             name => 'master2_pcp1').add_to_group('pe_ha_failover_pcp1')
  Target.new($master2,             name => 'master2_pcp2').add_to_group('pe_ha_failover_pcp2')
  Target.new("local://${master2}", name => 'master2_local').add_to_group('all')

  # Check to see if the original master is connected
  $master1_pcp1_connected = wait_until_available('master1_pcp1',
    wait_time       => 0,
    _catch_errors   => true,
  ).ok

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
      certname => "${master1}-double",
    ).first.value

    # Apply temporary pxp-agent config to ensure connectivity is retained
    # throughout agent re-cert process
    $pxp_config = run_task('pe_ha_failover::read_file', 'master1_pcp1',
      path => '/etc/puppetlabs/pxp-agent/pxp-agent.conf',
    ).first['content'].parsejson + {
      'ssl-ca-cert' => '/etc/puppetlabs/pxp-agent/tmp/ca.pem',
      'ssl-cert'    => '/etc/puppetlabs/pxp-agent/tmp/certificate.pem',
      'ssl-key'     => '/etc/puppetlabs/pxp-agent/tmp/key.pem',
    }

    apply('master1_pcp1') {
      class { 'pe_ha_failover::temporary_pxp_conf':
        key         => $certdata['key'],
        certificate => $certdata['certificate'],
        config      => $pxp_config.to_json,
      }
    }

    wait_until_available('master1_double_pcp1',
      wait_time => 180,
    )

    # This will "fail" when services start going down, interrupting things like
    # RBAC validation to retrieve job status.
    run_task('enterprise_tasks::disable_all_puppet_services', 'master1_double_pcp1',
      _catch_errors => true,
    )
  }

  # Promote the replica
  run_command(@("EOS"/L), 'master2_local')
    /opt/puppetlabs/bin/puppet infra promote replica \
    --topology mono-with-compile \
    --classifier-termini ${master2}:4433 \
    --puppetdb-termini ${master2}:8081 \
    --infra-agent-server-urls ${master2}:8140 \
    --infra-pcp-brokers ${master2}:8142 \
    --agent-server-urls ${master2}:8140 \
    --pcp-brokers ${master2}:8142 \
    --skip-agent-config \
    --yes
    |-EOS

  # Ensure both masters are connected
  wait_until_available(['master1_double_pcp2', 'master2_pcp2'],
    wait_time => 180,
  )

  # Restore the old master as the new replica
  run_plan('enterprise_tasks::enable_ha_failover',
    host              => 'master1_double_pcp2',
    caserver          => 'master2_local',
    topology          => 'mono-with-compile',
    skip_agent_config => true,
  )

  run_command(@("EOS"/L), 'master2_local')
    puppet node purge ${master1}-double;
    find /etc/puppetlabs/puppet/ssl -name ${master1}-double.pem -delete; \
    |-EOS
  run_command(@("EOS"/L), 'master1_pcp2')
    systemctl stop pxp-agent-double; \
    rm -rf /etc/puppetlabs/pxp-agent/tmp
    find /etc/puppetlabs/puppet/ssl -name ${master1}-double.pem -delete; \
    |-EOS

  return('plan complete')
}
