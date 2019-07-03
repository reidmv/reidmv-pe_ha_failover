# pe\_ha\_failover

#### Table of Contents

1. [Module Description](#module-description)
2. [Setup](#setup)
    * [What pe\_ha\_failover affects](#what-pe_ha_failover-affects)
    * [Setup requirements](#setup-requirements)
3. [Usage](#usage)
5. [Limitations](#limitations)

## Module description

This module provides a Bolt plan to fail over a Puppet Enterprise HA installation from a configured master to the configured replica and re-attach the old master as the new replica, inverting the HA master/replica relationship.

"Failback" is accomplished by running the failover plan again on the new configuration. The master-replica relationship will be again inverted, in effect restoring the relationship to its original state.

This operation is performed using only the Orchestrator transport. It does not require ssh.

## Setup

### What pe\_ha\_failover affects

The pe\_ha\_failover plan may, depending on the circumstances in which it is used:

* Promote a PE HA replica
* Re-purpose the original PE HA master and turn it into the new PE HA replica
* Revoke and re-issue the original PE HA master's certificate

### Setup Requirements

* The plan must be run from the current replica
* The plan must be run as root
* The following required modules must be available in and deployed to a Puppet environment:
    * reidmv-pe\_ha\_failover
    * puppetlabs-apply\_helpers
    * puppetlabs-bolt\_shim
    * puppetlabs-enterprise\_tasks
    * puppetlabs-pe\_infrastructure
    * puppetlabs-ruby\_task\_helper
    * puppetlabs-stdlib
* An inventory must be used which defines two groups: pe\_ha\_failover\_pcp1 and pe\_ha\_failover\_pcp2:
    * pe\_ha\_failover\_pcp1 must configure pcp credentials for the current HA master
    * pe\_ha\_failover\_pcp2 must configure pcp credentials for the current HA replica
    * The task-environment configured for each must contain the required modules
    * An example inventory.yaml:

            ---
            version: 2
            groups:
              - name: pe_ha_failover_pcp1
                config:
                  pcp:
                    service-url: https://master-1.dev36.puppet.vm:8143
                    cacert: /etc/puppetlabs/puppet/ssl/certs/ca.pem
                    token-file: /root/.puppetlabs/token
                    task-environment: production
              - name: pe_ha_failover_pcp2
                config:
                  pcp:
                    service-url: https://master-2.dev36.puppet.vm:8143
                    cacert: /etc/puppetlabs/puppet/ssl/certs/ca.pem
                    token-file: /root/.puppetlabs/token
                    task-environment: production
                    
* As a minimum requirement to successfully re-purpose the original master into the new replica, the pxp-agent service must be running before the plan is invoked.

## Usage

### Use cases

Tested = ✔️  
Untested =❓

* Perform an on-demand failover of a healthy HA master / replica pair [✔️]
* Promote a replica and attempt to re-purpose an unhealthy original master [❓]
* Perform a re-attachment of a previously unavailable master to a previously-promoted replica, re-purposing the old master as the new replica [❓]

### Running the plan

Example usage:

To ensure best results, quiesce the Puppet agent on relevent systems first. This includes the master, the replica, and database nodes in some architectures.

```
bolt task run pe_ha_failover::pause_puppet_agent \
  duration=30m \
  --target master-1.example.com \
  --target master-2.example.com \
  --target pdb-postgresql-1.example.com \
  --target pdb-postgresql-2.example.com
```

With the Puppet agent paused on these systems, perform the failover.

```
bolt plan run pe_ha_failover \
  --inventoryfile inventory.yaml \
  master=master-1.puppet.vm \
  replica=master-2.puppet.vm
```

For PE Extra Large deployments where Bolt is configured to use PuppetDB, parameters for healthy failover can be auto-identifed and the appropriate nodes' Puppet agents paused without additional user input required. This is not the default way to perform failover because if the master is unavailable, the ability to look this information up automatically is constrained prior to PE 2018.1.9.

```
bolt plan run pe_ha_failover::pe_xl
```

## Limitations

This module is only tested on and known to be compatible with the EL 7 platform.
