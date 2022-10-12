#!/bin/bash
apt-get update
apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg2
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
deb [arch=amd64] https://download.docker.com/linux/ubuntu xenial stable
EOF

# Install Docker CE
sudo apt-get update && sudo apt-get install -y \
  containerd.io=1.2.13-2 \
  docker-ce=5:19.03.11~3-0~ubuntu-xenial \
  docker-ce-cli=5:19.03.11~3-0~ubuntu-xenial
# Set up the Docker daemon
systemctl stop docker
modprobe overlay
echo '{"storage-driver": "overlay2"}' > /etc/docker/daemon.json
rm -rf /var/lib/docker/*
systemctl start docker

# Install kubernetes components
apt-get install -y kubernetes-cni=0.8.7-00
apt-get install -y \
  kubelet=1.1.21.14-00 \
  kubeadm=1.1.21.14-00 \
  kubectl=1.1.21.14-00
