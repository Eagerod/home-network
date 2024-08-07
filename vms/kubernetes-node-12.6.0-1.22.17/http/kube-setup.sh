#!/usr/bin/env sh
#
# Install a specific Kubernetes version.
# Mostly taken from https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
#
# Note: Will be run on VM imaging, so must run as superuser.
#

if [ "$(id -u)" -ne 0 ]; then
  echo >&2 "Must run $0 as root"
  exit 1
fi

apt-get install -y \
  conntrack \
  socat

CNI_VERSION="v1.4.1"
ARCH="amd64"
mkdir -p /opt/cni/bin
curl -L "https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-linux-${ARCH}-${CNI_VERSION}.tgz" | tar -C /opt/cni/bin -xz


CRICTL_VERSION="v1.29.0"
ARCH="amd64"
curl -L "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-${ARCH}.tar.gz" | tar -C /usr/bin/ -xz

RELEASE="${RELEASE:-v1.21.14}"
ARCH="amd64"
curl -L https://storage.googleapis.com/kubernetes-release/release/"${RELEASE}"/bin/linux/${ARCH}/kubeadm -o /usr/bin/kubeadm
curl -L https://storage.googleapis.com/kubernetes-release/release/"${RELEASE}"/bin/linux/${ARCH}/kubelet -o /usr/bin/kubelet
curl -L https://storage.googleapis.com/kubernetes-release/release/"${RELEASE}"/bin/linux/${ARCH}/kubectl -o /usr/bin/kubectl
chmod +x /usr/bin/kubeadm /usr/bin/kubelet /usr/bin/kubectl


RELEASE_VERSION="v0.4.0"
curl -sSL "https://raw.githubusercontent.com/kubernetes/release/${RELEASE_VERSION}/cmd/kubepkg/templates/latest/deb/kubelet/lib/systemd/system/kubelet.service" | tee /etc/systemd/system/kubelet.service
mkdir -p /usr/lib/systemd/system/kubelet.service.d
curl -sSL "https://raw.githubusercontent.com/kubernetes/release/${RELEASE_VERSION}/cmd/kubepkg/templates/latest/deb/kubeadm/10-kubeadm.conf" | tee /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf
