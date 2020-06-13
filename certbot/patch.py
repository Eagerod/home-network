#!/usr/bin/env python
#
# This is a stupid python script I have to write because the certbot image
#   doesn't come with curl installed, and the wget binary bundled with the
#   busybox distro it's built off of doesn't seem to support different HTTP
#   methods.
# There may be a way to get around it, but the time to figure that out probably
#   isn't worth it.
import sys

import requests

if __name__ == '__main__':
	if len(sys.argv) != 4:
		print('Usage:', sys.argv[0], 'auth_header', 'patch_body', 'host')

	auth_header, patch_body, host = sys.argv[1:]

	response = requests.patch(
		url=host,
		verify=False,
		headers={
			'Authorization': auth_header,
			'Content-Type': 'application/merge-patch+json'
		},
		data=patch_body
	)

	print("HTTP status code: {}".format(response.status_code))

	if not response.ok:
		sys.exit(-1)
