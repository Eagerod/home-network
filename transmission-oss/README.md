# OSS Transmission

Simple transmission container that attaches to a provided download directory.

This particular installation is meant for organizing all Open Source Software torrents.

Because all services run in Docker, the `watch-dir-force-generic` parameter needs to be set to true in `settings.json`.
This may not be required specifically in the case where the host machine is a Linux machine and the directory is local, but since that's not how this is meant to be configured, it's set this way.

# ToDos

- [ ] On Windows, using the host volume set up, the container will sometimes not see all files in the downloads directory, and only actually see one of the files in the downloads directory.
