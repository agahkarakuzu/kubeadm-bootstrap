#!/bin/bash
# immediately exit if any command within the script returns a non-zero exit 
# status (indicating an error)
set -e

# Use config file to initialize ctl plane
kubeadm init --config kube-config.yaml


# To use the cluster
# mkdir -p $HOME/.kube
# cp --remove-destination /etc/kubernetes/admin.conf $HOME/.kube/config
# chown ${SUDO_UID} $HOME/.kube/config

mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# Deploying Flannel (a pod network) with kubectl
# VERSION 0.25.0
# Read more https://github.com/flannel-io/flannel

kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/master/manifests/calico-vxlan.yaml
#kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/canal.yaml
#kubectl apply -f https://github.com/flannel-io/flannel/releases/download/v0.25.0/kube-flannel.yml


# ===========
# In Kubernetes, "taints" and "tolerations" are mechanisms used to control which nodes can accept which pods.
# By default, the master nodes HAVE a taint that prevents regular pods from being scheduled on them. This is to 
# ensure that the control plane has enough resources to manage the cluster effectively.
# E.g., in BinderHub, this means a user can be assigned to the master node for 
# a session. 
# ============

# Removing the taints on the control plane so that we can schedule pods on it.
kubectl taint nodes --all node-role.kubernetes.io/master-

# ================ INSTALL HELM
# Official source: https://helm.sh/docs/intro/install/#from-script
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash