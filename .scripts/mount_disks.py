import subprocess
import sys

import yaml


def print_shell_command(args):
    print ' '.join([a if ' ' not in a else '"{}"'.format(a) for a in args])


with open(sys.argv[1]) as f:
    volumes_yaml = yaml.load(f)

for volume in volumes_yaml.get('volumes', {}):
    mkdir_params = ['mkdir', '-p', volume['local']]
    print_shell_command(mkdir_params)

    # mkdir will fail if the directory to be mounted to already exists. Ignore
    #   failures.
    proc = subprocess.Popen(mkdir_params)
    proc.wait()

    umount_params = ['umount', volume['local']]
    print_shell_command(umount_params)
    # The unmount will fail if there's nothing already mounted there, so don't
    #   bother checking the returncode on this call.
    proc = subprocess.Popen(umount_params)
    proc.wait()

    mount_params = [
        'mount',
        '-t', volume['type'],
        volume['remote'],
        volume['local'],
    ]

    if 'extras' in volume:
        mount_params.insert(3, '-o')
        mount_params.insert(4, volume['extras'])

    print_shell_command(mount_params)
    proc = subprocess.Popen(mount_params)
    proc.wait()

    if proc.returncode != 0:
        print >> sys.stderr, 'Failed to mount directory at {}'.format(volume['remote'])
        sys.exit(-1)
