#!/usr/bin/env sh
#
# Script to start up the installation of all dependencies required to start up
#   up the network on a fresh machine.
# This script used to run on Ubuntu, but I decided to switch it up for CentOS.
#
# This can be downloaded and installed with a:
#
# curl https://raw.githubusercontent.com/Eagerod/home-network/master/bootstrap.sh | sh

set -e

POD_NETWORK_CIDR=10.244.0.0/16

# Check to make sure this script is running as root.
# Script needs to change some configurations that need root.
verify_is_root() {
    if [ ${EUID} != 0 ]; then
        echo >&2 "Bootstrap being run an non-superuser. Cannot continue."
        exit 1
    fi
}

# Check to make sure this is running on a Linux machine.
verify_is_linux() {
    if [ "$$(uname)" != "Linux" ]; then
        echo >&2 "Bootstrap being run on a $(uname) machine. Cannot continue."
        exit 1
    fi
}

# Modify the string given from the user to lowercase it, and potentially
#   expand on it before echoing out a more clean version of the operation.
verify_bootstrap_op() {
    op=$(echo "$1" | awk '{print tolower($0)}')

    if [ "$op" == "m" ]; then
        op="master"
    elif [ "$op" == "k" ]; then
        op="kubelet"
    fi

    if [ "$op" != "master" ] && [ "$op" != "kubelet" ]; then
        echo >&2 "Must bootstrap a master or a kubelet.";
        exit 1
    fi
}

# Install openssh-server, and configure my usual set of rules.
# All machines should be able to be sshed into to run any kind of debugging.
setup_openssh_server() {
    yum install -y openssh-server

    sed -i -r 's/^[#\s]*(PasswordAuthentication).*$$/\1 no/' /etc/ssh/sshd_config
    sed -i -r 's/^[#\s]*(PermitRootLogin).*$$/\1 prohibit-password/' /etc/ssh/sshd_config

    systemctl enable sshd
    systemctl start sshd
}

# Install whatever packages are needed regardless of master vs. kubelet
install_common_deps() {
    cat > /etc/yum.repos.d/kubernetes.repo <<EOF
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kube*
EOF

    yum install -y \
        docker \
        nfs-utils \
        kubelet \
        kubeadm \
        kubectl \
        --disableexcludes=kubernetes

    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json <<EOF
{
    "exec-opts": [
        "native.cgroupdriver=systemd"
    ],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m"
    },
    "storage-driver": "overlay2",
    "storage-opts": [
        "overlay2.override_kernel_check=true"
    ]
}
EOF
    echo "" > /etc/sysconfig/docker-storage
    echo "" > /etc/sysconfig/docker-storage-setup
    sed -i '/--exec-opt native.cgroupdriver/d' /usr/lib/systemd/system/docker.service
    sed -i 's/--log-driver=journald//' /etc/sysconfig/docker

    # mkdir -p /etc/systemd/system/docker.service.d

    cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

    # It seems like flannel will automatically update this with a subnet that
    #   hasn't already been allocated.
    mkdir -p /run/flannel
    cat > /run/flannel/subnet.env <<EOF
FLANNEL_NETWORK=${POD_NETWORK_CIDR}
FLANNEL_SUBNET=10.244.0.1/24
FLANNEL_MTU=1450
FLANNEL_IPMASQ=true
EOF

    echo 1 > /proc/sys/net/ipv4/ip_forward
    sysctl -p

    sed -i '/ swap / s/^/#/' /etc/fstab
    swapoff -a

    systemctl daemon-reload
    systemctl enable docker 
    systemctl enable kubelet
    systemctl start docker
    systemctl start kubelet

    # setenforce 0

    # sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
}

verify_is_root || exit 5
verify_is_linux || exit 10

echo "This is my Kubernetes set up script."
read -p "Are we setting up a [master] node, or a [kubelet]? " bootstrap_op

bootstrap_op=$(verify_bootstrap_op $bootstrap_op) || exit 15

setup_openssh_server || echo 20

install_common_deps

if [ "${bootstrap_op}" = "kubelet" ]; then
    firewall-cmd --permanent --add-port=10250/tcp
    firewall-cmd --permanent --add-port=10251/tcp
    firewall-cmd --permanent --add-port=10255/tcp
    firewall-cmd --reload

    echo "The kubelet should be ready to go. Join to the master using the output of:"
    echo "  kubeadm token create --print-join-command"
elif [ "${bootstrap_op}" = "master" ]; then
    firewall-cmd --permanent --add-port=6443/tcp
    firewall-cmd --permanent --add-port=2379-2380/tcp
    firewall-cmd --permanent --add-port=10250/tcp
    firewall-cmd --permanent --add-port=10251/tcp
    firewall-cmd --permanent --add-port=10252/tcp
    firewall-cmd --permanent --add-port=10255/tcp
    firewall-cmd --reload

    kubeadm init --pod-network-cidr=${POD_NETWORK_CIDR}
else
    echo >&2 "Invalid node type. Must bootstrap a master or a kubelet."
    exit 20
fi
