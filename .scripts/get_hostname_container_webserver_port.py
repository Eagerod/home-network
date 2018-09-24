import re
import sys

import yaml

# Service, IP pairings that should not be serving up HTTP on the specified port.
IGNORE_PAIRS = [
    ('mongodb', 27017),
    ('mysql', 3306),
    ('redis', 6379)
]

with open(sys.argv[1]) as f:
    compose_yaml = yaml.load(f)

for service, defn in compose_yaml.get('services', {}).iteritems():
    if 'ports' not in defn or 'hostname' not in defn:
        continue

    port = re.sub('[^0-9]', '', defn['ports'][0].split(':')[1])

    if (defn['hostname'], int(port)) in IGNORE_PAIRS:
        continue

    print '{} {}'.format(defn['hostname'], port)
