# MongoDB

Pure base MongoDB 3.7 image with just an attached volume.

# ToDos

- [ ] Find out if it's possible for OS X/Windows hosts to actually run the storage layer, or if it has to always be using named volumes.
- [ ] Find a reasonable way of making sure that backups scale. Currently, the entire DB is backed up hourly. It will be easy to move this to daily, once the job gets long enough, but there will be different requirements from different collections. Some should be backed up hourly, some daily, some even less frequently.
