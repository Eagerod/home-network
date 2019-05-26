# Util Server

The dumping grounds for things that don't need to be dedicated containers.

Just a container I can SSH into and mess around with different services without any damage being persisted.

# ToDos

- [ ] Create a git user that can be used with a proper home directory that can be used to keep git URLs on clients simple, rather than needing to know the directory structure of the host machine.
- [ ] Properly keep tabs on the service's own server key, so that any time the network needs to get brought up again, all clients recognize it.
- [ ] Figure out what's going on with `authorized_keys`. Should they be in Git, should they be ignored?
- [ ] Instead of building everything in the container, build it locally, and copy to the container. There's no good reason for the container to be nearly a gig.
