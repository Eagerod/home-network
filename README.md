# Home network configuration templates

This repo holds configurations for my home network.

# Booting a fresh cluster

```
hope vm create beast1 load-balancer api
hope vm start beast1 api
hope vm ip beast1 api
sshpass -p "$VM_MANAGEMENT_PASSWORD" hope node ssh api
hope node hostname api api
hope node init --force api

hope vm create beast1 kubernetes-node-12.6.0-1.23.17 home-master-01
hope vm start beast1 home-master-01
hope vm ip beast1 home-master-01
sshpass -p "$VM_MANAGEMENT_PASSWORD" hope node ssh home-master-01
hope node hostname home-master-01 home-master-01
hope node init --force home-master-01

hope vm create beast1 kubernetes-node-12.6.0-1.23.17 home-node-01
hope vm start beast1 home-node-01
hope vm ip beast1 home-node-01
sshpass -p "$VM_MANAGEMENT_PASSWORD" hope node ssh home-node-01
hope node hostname home-node-01 home-node-01
hope node init --force home-node-01

...
```
