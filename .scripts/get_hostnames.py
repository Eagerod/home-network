import sys

import yaml

with open(sys.argv[1]) as f:
    compose_yaml = yaml.load(f)

for service, defn in compose_yaml.get('services', {}).iteritems():
    if 'hostname' not in defn:
        continue

    print defn['hostname']
