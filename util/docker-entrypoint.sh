#!/bin/sh
#
# Push variables into bash profile, so container environments are available in
#   ssh sessions.
echo "export DEFAULT_BLOBSTORE_WRITE_ACL=${DEFAULT_BLOBSTORE_WRITE_ACL}" >> ~/.bash_profile 
echo "export DEFAULT_BLOBSTORE_READ_ACL=${DEFAULT_BLOBSTORE_READ_ACL}" >> ~/.bash_profile 

echo "export MULTI_REDDIT_SUBS_LOCATION=${MULTI_REDDIT_SUBS_LOCATION}" >> ~/.bash_profile
echo "export MULTI_REDDIT_SAVED_LOCATION=${MULTI_REDDIT_SAVED_LOCATION}" >> ~/.bash_profile

echo 'export PATH=/usr/local/bin:$PATH' >> ~/.bash_profile

exec /usr/sbin/sshd -D -e
