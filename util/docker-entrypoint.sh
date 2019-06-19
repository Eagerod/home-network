#!/bin/sh
#
# Push variables into bash profile, so container environments are available in
#   ssh sessions.
echo "export DEFAULT_BLOBSTORE_WRITE_ACL=${DEFAULT_BLOBSTORE_WRITE_ACL}" >> ~/.bash_profile 
echo "export DEFAULT_BLOBSTORE_READ_ACL=${DEFAULT_BLOBSTORE_READ_ACL}" >> ~/.bash_profile 

echo "export MULTI_REDDIT_SUBS_LOCATION=${MULTI_REDDIT_SUBS_LOCATION}" >> ~/.bash_profile
echo "export MULTI_REDDIT_SAVED_LOCATION=${MULTI_REDDIT_SAVED_LOCATION}" >> ~/.bash_profile

echo 'export PATH=/usr/local/bin:$PATH' >> ~/.bash_profile

git config --global user.email "noreply@aleemhaji.com"
git config --global user.name "Aleem Haji"

if [ ! /var/lib/git ]; then
    echo >&2 "Git dir not found, skip creation of repository manager"
elif [ -d /var/lib/git ] & [ ! -d /var/lib/git/repositories.git ]; then
    echo >&2 "No repository manager found. Creating..."

    cd /var/lib/git
    mkdir -p repositories.git
    git -C repositories.git init --bare

    cd /root/repository-manager
    git init
    sed 's?root_dir:.*?root_dir: /var/lib/git?' repositories.template.yaml > repositories.yaml
    git add repositories.yaml
    git commit -m "initial commit to add repository manager"
    git remote add origin /var/lib/git/repositories.git
    git push origin master

    cp /root/repository-manager/pre-receive.py /var/lib/git/repositories.git/hooks/pre-receive
    chmod 755 /var/lib/git/repositories.git/hooks/pre-receive
    cd /
fi

exec /usr/sbin/sshd -D -e
