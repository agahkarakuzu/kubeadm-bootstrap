#!/bin/bash

# Use the latest versions of the 
# existing packages.
apt-get update

# ============================================= Pre-install sys configs
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

# ============================================= Misc installations

# Install prereqs
apt install -y \
  curl \
  gnupg2 \
  software-properties-common \
  apt-transport-https \
  ca-certificates

# ============================================= Containerd
# Install
# Configure for systemd 
# Install docker as well

# Install containerd runtime
# Kubernetes has deprecated Docker as a container runtime in favor of containerd (2020).
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmour -o /etc/apt/trusted.gpg.d/docker.gpg
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

apt update
apt install -y \
  containerd.io \
  docker.io

# Change the SystemdCgroup setting from false to true
# kube-config.yaml MUST set cgroupDriver to systemd for this.
containerd config default | tee /etc/containerd/config.toml >/dev/null 2>&1
sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

# Apply changes 
systemctl restart containerd
systemctl enable containerd

# ============================================= K8S
# Install 1.29
# https://kubernetes.io/blog/2023/08/15/pkgs-k8s-io-introduction

# Add the Kubernetes signing key and repository.
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
# Overwrite k8s config.
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update

# Install
apt-get install -y \
  kubelet=1.29.0 \
  kubeadm=1.29.0 \
  kubectl=1.29.0

# Freeze 
apt-mark hold kubelet kubeadm kubectl

# ============================================= DONE
# Terraform will be used to initialize 
# On master node: init-master