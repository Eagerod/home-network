Various templates and such for managing things that keep the cluster neat.

Each namespace ships with:
- A set of docker registry secrets
- A `CronJob` to copy SSL certs from filesystem to Kubernetes `Secret`
- A `CronJob` to kill pods whose containers have > 10 restarts
- A `CronJob` to delete old manual job runs
