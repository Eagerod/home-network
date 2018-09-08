import sys

import yaml

with open(sys.argv[1]) as f:
    compose_yaml = yaml.load(f)

for volume, defn in compose_yaml.get('volumes', {}).iteritems():
    if not defn.get('external', False):
        continue
    print volume
