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

  $pdb_databases = puppetdb_query(@("PQL")).map |$node| { $node['certname'] }
    resources[certname] {
      type = "Class" and
      title = "Puppet_enterprise::Profile::Database" and
      !(certname = "${master[0]}") and
      !(certname = "${replica[0]}") }
    | PQL

  # During the promotion process, several Puppet agent runs will be
  # orchestrated.  To avoid a race condition (and bug) between the agent and
  # orchestrated runs, we will pause self-activated agent runs before beginning
  # the failover operation.
  run_task('pe_ha_failover::pause_puppet_agent', $master + $replica + $pdb_databases,
    duration => '30m',
  )

  $plan_result = run_plan('pe_ha_failover',
    master  => $master,
    replica => $replica,
  )

  return($plan_result)
}
