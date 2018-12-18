#!/usr/bin/env sh
#
# Script to start up the installation of all dependencies required to start up
#   up the network on a fresh machine.
apt-get update -y
apt-get install make

# If this isn't in a directory that already has the `bootstrap.make` file,
#   download it from GitHub, and then run its default recipe.
if [ ! -f bootstrap.make ]; then
    curl https://raw.githubusercontent.com/Eagerod/home-network/master/bootstrap.make -o bootstrap.make
fi

make -f bootstrap.make
