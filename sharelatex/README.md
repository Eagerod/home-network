# ShareLaTeX

ShareLaTeX base image with some LaTeX packages installed.

# ToDos

- [ ] Find out if it's possible for OS X/Windows hosts to actually run the storage layer, or if it has to always be using named volumes.
- [ ] Debug why the service will consume 100% CPU without much warning.
- [ ] See if there's a way of optimizing the installation process for all the `tlmgr` packages. Having them all install serially takes way too long.
