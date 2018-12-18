#!/usr/bin/env python
#
# Looks in the directory above this one, and creates the Markdown tables that
#   can be included in the readme.
# Can't make the table for individual containers.
import collections
import operator
import os
import re


SCRIPT_DIR = os.path.dirname(__file__)
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)


def print_tuple_list_as_table(l):
    lens = map(lambda a: max(a, key=len), zip(*l))
    lens = [len(a) + 2 for a in lens]
    for a in l:
        print ('| {} ' * len(a)).format(*['`{}`'.format(b).ljust(lens[i]) for i, b in enumerate(a)])


NfsShare = collections.namedtuple('NfsShare', ['sharepath', 'mountpoint'])
LocalVolume = collections.namedtuple('LocalVolume', ['mountpoint', 'localpath'])

nfs_shares = []
local_volumes = []


with open(os.path.join(PROJECT_DIR, 'nfs_volumes.txt')) as f:
    for s in f.readlines():
        nfs_shares.append(NfsShare(*re.split('\s', s.strip())))

with open(os.path.join(PROJECT_DIR, 'local_mounts.txt')) as f:
    for s in f.readlines():
        local_volumes.append(LocalVolume(*re.split('\s', s.strip())))

nfs_shares.sort(key=operator.itemgetter(0))
local_volumes.sort(key=operator.itemgetter(0))

print_tuple_list_as_table(nfs_shares)
print '=' * 15
print_tuple_list_as_table(local_volumes)
