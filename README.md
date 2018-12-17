# Home network configuration templates

**Note:** In the interest of brevity, where not otherwise explicitly stated, this readme should be read as though it strictly focuses on running on Linux.

This repo holds configurations for my home network.
It includes docker images, or host-modifying make commands that will allow any machine to be turned into a home network host without needing to configure much else.

*Note:* There's still a lot of "much else", but every time something new is done, the hope if that the gap of "much else" closes.

# Existing projects

- [Firefly III](/firefly-iii)
- [MongoDB](/mongodb)
- [MySQL](/mysql)
- [NGINX](/nginx)
- [Pi-hole](/pi-hole)
- [Plex](/plex)
- [Redis](/redis)
- [Resilio Sync Server](/resilio-server)
- [ShareLaTeX](/sharelatex)
- [Transmission (OSS)](/transmission-oss)
- [UniFi Controller](/unifi)
- [Util Server](/util)

[//]: # (# Service Name)
[//]: # ()
[//]: # (Description of the service/image/configuration, whatever)
[//]: # ()
[//]: # (# ToDos)
[//]: # ()
[//]: # (- [ ] Something that should be fixed with the current configuration/usage of the service)

# Volumes/Mounts

This project involves keeping a lot of docker containers running, and ensuring that their contents are appropriately organized so that they can be backed up.
The project currently doesn't have an especially functional method of managing volumes, or their backups, especially across containers or shares.
See the todos for volumes and backups for a little more on that.

In order for docker and network shares to behave nicely, and still follow some reasonable conventions, network shares are mounted to `/mnt` on the host machine, and symlinked to a more appropriate place on the host.
They're then mounted to containers, sometimes in the same place as on the host, sometimes at other paths, when that's more convenient.

This system assumes there is a centralized storage server that all network shares are hosted from.
Other options may be considered in the future if need be.

## Network Shares

Network shares are divided out into groupings of services.
Individual directories within the mount points can be symlinked as needed.

| Network Mount      | Mount Point      | Description
| ================== | ================ | =============
| `/share/appdata`   | `/mnt/appdata`   | Backups
| `/share/backups`   | `/mnt/backups`   | Databases
| `/share/db`        | `/mnt/db`        | Downloads
| `/share/downloads` | `/mnt/downloads` | Other Storage

**Note:** On deployments where everything is local to a single host machine, this section doesn't apply.

## Host Symlinks

The host machines will add the symlinks they need to the directories within their mounts that they need to access resources.

| Mount Path                      | Host Path                   | Description
| =============================== | =========================== | =============
| `/mnt/appdata/git`              | `/var/lib/git`              | Git repositories.
| `/mnt/appdata/plex`             | `/var/lib/plex`             | Plex metadata.
| `/mnt/appdata/resilio-sync`     | `/var/lib/.sync`            | Reslio Sync metadata.
| `/mnt/appdata/sharelatex`       | `/var/lib/sharelatex`       | ShareLaTeX files not included in DB.
| `/mnt/appdata/transmission-oss` | `/var/lib/transmission-oss` | Transmission metadata for open source software.
| `/mnt/backups`                  | `/var/lib/backups`          | All backups from any containers.
| `/mnt/db/mongodb`               | `/var/lib/mongodb`          | MongoDB storage.
| `/mnt/db/mysql`                 | `/var/lib/mysql`            | MySQL storage.
| `/mnt/downloads/oss`            | `/var/lib/downloads/oss`    | Open source software downloads.

**Note:** On deployments where everything is local to a single host machine, this section doesn't apply.

## Container Mounts

Each container may mount host paths wherever they need to.
These are documented here so that they can be grokked easily.

| Host Path                   | Container          | Container Path
| =========================== | ================== | ==========================
| `/var/lib/.sync`            | `resilio-sync`     | `/.sync`
| `/var/lib/backups`          | `resilio-server`   | `/var/lib/resilio-folders`
| `/var/lib/backups`          | `util`             | `/var/lib/backups`
| `/var/lib/downloads/oss`    | `transmission-oss` | `/var/lib/downloads`
| `/var/lib/git`              | `util`             | `/var/lib/git`
| `/var/lib/mongodb`          | `mongodb`          | `/data/db`
| `/var/lib/mysql`            | `mysql`            | `/var/lib/data`
| `/var/lib/plex`             | `plex`             | `/config`
| `/var/lib/sharelatex`       | `sharelatex`       | `/var/lib/sharelatex`
| `/var/lib/transmission-oss` | `transmission-oss` | `/var/lib/transmission-daemon`


# Major ToDos

- [ ] Properly create users that can cross the VM boundary with OS X/Windows where possible. 
- [ ] Get the Makefile set up so it can properly invalidate autogenerated files when the sources change.
- [ ] Make sure that all Dockerfiles have the appropriate number of layers. There are a lot that run simple commands back to back in different layers, wasting time + space.
- [ ] Get the whole thing configured to work with Docker Swarm, so it can be run on an array of hosts, rather than just one.
- [ ] Get health checks set up on the containers where a health check makes sense (probably all of them.)
- [ ] Figure out a more sustainable way of managing backups/crons.
- [ ] Volume mounting logic may be a little platform specific and needs help.
