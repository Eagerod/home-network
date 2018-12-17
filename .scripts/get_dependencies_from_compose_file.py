import sys

import yaml


service = sys.argv[1]
compose_file = sys.argv[2]

with open(compose_file) as f:
    compose_yaml = yaml.load(f)

if 'services' not in compose_yaml:
    raise Exception('Did not find compose services in {}'.format(compose_file))

if service not in compose_yaml['services']:
    raise Exception('Service {} not found in compose file {}'.format(service, compose_file))

service_defn = compose_yaml['services'][service]

for dep in service_defn.get('depends_on', []):
    print dep
