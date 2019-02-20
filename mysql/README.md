# MySQL

Fairly simple MySQL server set up.

# ToDos

- [ ] Find out if it's possible for OS X/Windows hosts to actually run the storage layer, or if it has to always be using named volumes.
- [ ] Make the initial installation process a bit more smooth. It currently relies on starting the server up with a few different configurations, and it's not extremely fluid.
- [ ] Find a reasonable way of making sure that backups scale. Currently, the entire DB is backed up hourly. It will be easy to move this to daily, once the job gets long enough, but there will be different requirements from different tables. Some should be backed up hourly, some daily, some even less frequently.