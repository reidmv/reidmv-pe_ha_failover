plan pe_ha_failover::pe_xl(
  # No parameters
) {

  $master = puppetdb_query(@("PQL")).map |$node| { $node['certname'] }
    resources[certname] { 
      type = "Class" and
      title = "Puppet_enterprise::Profile::Certificate_authority" }
    | PQL

  $replica = puppetdb_query(@("PQL")).map |$node| { $node['certname'] }
    resources[certname] { 
      type = "Class" and
      title = "Puppet_enterprise::Profile::Primary_master_replica" }
    | PQL

  if ($master.size != 1) or ($replica.size != 1) {
    fail_plan("Unable to lookup inputs. Found: ${master} for master; ${replica} for replica.")
  }

  $pdb_databases = puppetdb_query(@("PQL")).map |$node| { $node['certname'] }
    resources[certname] {
      type = "Class" and
      title = "Puppet_enterprise::Profile::Database" and
      !(certname = "${master[0]}") and
      !(certname = "${replica[0]}") }
    | PQL

  # During the promotion process, the old master will be deactivated in
  # PuppetDB. To ensure that Puppet doesn't remove the RBAC rules allowing the
  # old master's certname to connect, we temporarily pause Puppet agent runs on
  # the PuppetDB PostgreSQL nodes.
  run_task('pe_ha_failover::pause_puppet_agent', $pdb_databases,
    duration => '30m',
  )

  $plan_result = run_plan('pe_ha_failover',
    master  => $master,
    replica => $replica,
  )

  return($plan_result)
}
