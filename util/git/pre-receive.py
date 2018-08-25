#!/usr/bin/env python

import os
import re
import subprocess
import sys

import yaml


class InvalidDefinitionError(ValueError):
    pass


class InvalidDirectoryError(ValueError):
    pass


class GitChange(object):
    def __init__(self, stdin_line):
        components = stdin_line.split(' ')
        self.old_value = components[0]
        self.new_value = components[1]
        self.ref_name = components[2].strip()


class Repository(object):
    def __init__(self, root, d):
        if 'name' not in d:
            raise InvalidDefinitionError('Invalid repository definition: name')
        self.path = os.path.join(root, d['name'])
        if not re.match('\.git$', self.path):
            self.path = '{}.git'.format(self.path)

    def validate_presence(self):
        if os.path.isdir(self.path):
            is_bare = subprocess.check_output(['git', 'rev-parse', '--is-bare-repository'])
            if is_bare == 'false':
                raise InvalidDirectoryError('Directory passed in that is not a git repository')
            return

        os.makedirs(self.path)
        subprocess.call(['git', 'init', '--bare'], cwd=self.path)
        print 'Created repository at {}'.format(self.path)


class RepositoryCollection(object):
    def __init__(self, d):
        if 'repositories' not in d:
            raise InvalidDefinitionError('Invalid repository definition: repositories')
        root = d['root_dir']
        self.repositories = [Repository(root, r) for r in d['repositories']]


if __name__ == '__main__':
    print 'Checking updates for new repositories'
    for line in sys.stdin.readlines():
        change = GitChange(line)
        if change.ref_name != 'refs/heads/master':
            continue

        contents = subprocess.check_output(['git', 'show', '{}:repositories.yaml'.format(change.new_value)])
        if contents:
            try:
                collection = RepositoryCollection(yaml.load(contents))
                for repository in collection.repositories:
                    repository.validate_presence()
            except InvalidDefinitionError as e:
                print e.message
                exit(-1)
            except InvalidDirectoryError as e:
                print e.message
                exit(-1)
