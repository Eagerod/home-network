import subprocess
import sys

import yaml


with open(sys.argv[1]) as f:
    volumes_yaml = yaml.load(f)

for volume in volumes_yaml.get('volumes', {}):
    params = [
        'mount',
        '-t', volume['type'],
        volume['remote'],
        volume['local'],
    ]

    if 'extras' in volume:
        params.insert(3, '-o')
        params.insert(4, volume['extras'])

    proc = subprocess.Popen(['mkdir', '-p', volume['local']])
    proc.wait()

    if proc.returncode != 0:
        print >> sys.stderr, 'Failed to create directory in {}'.format(volume['local'])
        sys.exit(-1)

    # The unmount will fail if there's nothing already mounted there, so don't
    #   bother checking the returncode on this call.
    proc = subprocess.Popen(['umount', volume['local']])
    proc.wait()

    print ' '.join([p if ' ' not in p else '"{}"'.format(p) for p in params])
    proc = subprocess.Popen(params)
    proc.wait()

    if proc.returncode != 0:
        print >> sys.stderr, 'Failed to mount directory at {}'.format(volume['remote'])
        sys.exit(-1)
