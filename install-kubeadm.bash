#!/bin/bash
set -e

apt-get update

# :::[[Pre-install sys configs]]:::::::::::::::::::::::::::::::::::::::::::::
# Disable swap
# Enable overlay file system 
# Lod br_netfilter kernel module (VxLAN)

# Disabling swap (swapoff -a) and commenting out swap entries 
# in /etc/fstab are done before installing Kubernetes because 
# Kubernetes requires swap to be disabled for optimal performance
# and stability.
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Create a configuration file that ensures the following
# kernel modules are loaded at boot time.
tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF

# overlay: Enables the overlay filesystem, which is needed for Docker's 
# storage driver to manage container filesystems efficiently.
modprobe overlay
# br_netfilter: Ensures that the Linux bridge module is loaded, which is required for 
# traffic for communication between Kubernetes pods across the cluster
modprobe br_netfilter

# Ensure that IPv4/6 packets are properly processed by iptables for bridged traffic.
# Enable IP forwarding (necessary for routing between different network interfaces).
tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

# Apply these system settings
sysctl --system

# :::[[Misc Installations]]::::::::::::::::::::::::::::::::::::::::::::;;;;

# Install prereqs
apt install -y \
  curl \
  gnupg2 \
  software-properties-common \
  apt-transport-https \
  ca-certificates \
  gpg

# :::[[Container runtimes]]:::::::::::::::::::::::::::::::::::::::::::::

# Install containerd & docker
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update

# Select the OLDEST version among the available versions in the stable repository
# provided for THIS release of Ubuntu (using 24.04 (latest LTS) as of May 2024)
VERSION_DOCKER=$(apt-cache madison docker-ce | awk '{ print $3 }' | sort -V | head -n 1)
VERSION_CONTAINERD=$(apt-cache madison containerd.io | awk '{ print $3 }' | sort -V | head -n 1)

# By default, BinderHub will build images with the host Docker installation.
# Hence we need to install docker in addition to containerd.
apt install -y containerd.io=$VERSION_CONTAINERD \
  docker-ce=$VERSION_DOCKER \
  docker-ce-cli=$VERSION_DOCKER

# CGROUP AND STORAGE DRIVER COMPATIBILITY BETWEEN CONTAINER RUNTIMES & K8S
# Since Ubuntu 21.01 cgroupv2 is used by default, for which systemd is the default driver.

# Docker uses overlay2 as the preferred storage driver for all currently supported Linux distributions,
# and requires no extra configuration.

# Similarly, containerd (snapshotter = "overlayfs") is uses overlay by default.

# Change the SystemdCgroup setting from false to true to set cgroup as systemd
# https://github.com/containerd/containerd/blob/main/docs/cri/config.md
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml >/dev/null 2>&1
sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

# Note: kube-config.yaml will set cgroupDriver to systemd for the k8s cluster.

# Pause container version compatibility
SANDBOX_IMAGE=registry.k8s.io/pause:3.9
sudo sed -i.bak -E "s|sandbox_image = \".*\"|sandbox_image = \"$SANDBOX_IMAGE\"|" "/etc/containerd/config.toml"
# Apply changes 
systemctl restart containerd.service
systemctl enable containerd.service
systemctl enable docker.service

# :::[[Kubernetes]]:::::::::::::::::::::::::::::::::::::::::::::

# Add the Kubernetes signing key and repository.
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

apt-get update

# Install kubernetes components
apt install -y kubeadm=1.28.1-1.1 kubelet=1.28.1-1.1 kubectl=1.28.1-1.1
apt-mark hold kubelet kubeadm kubectl

touch k8s-install-success