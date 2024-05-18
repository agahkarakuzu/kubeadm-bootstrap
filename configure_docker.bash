#!/bin/bash

# This is sub-optimal, manually attempts to have all the nodes
# login to provate registry.

# Ideally, this should have been dealt with @k8s level.
sudo docker login $1 --username $2 --password $3
sudo chown -R ubuntu /home/ubuntu/.docker
sudo chgrp -R ubuntu /home/ubuntu/.docker
nodes=$(kubectl get nodes --selector='!node-role.kubernetes.io/master' -o jsonpath='{range .items[*].status.addresses[?(@.type=="InternalIP")]}{.address} {end}')
echo $nodes
for n in $nodes;
do
        scp -o StrictHostKeyChecking=no /home/ubuntu/.docker/config.json root@$n:/var/lib/kubelet/config.json
done
sudo cp /home/ubuntu/.docker/config.json /var/lib/kubelet/
