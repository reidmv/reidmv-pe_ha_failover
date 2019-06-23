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

```
bolt plan run pe_ha_failover \
  --inventoryfile inventory.yaml \
  master=master-1.puppet.vm \
  replica=master-2.puppet.vm
```

## Limitations

This module is only tested on and known to be compatible with the EL 7 platform.
