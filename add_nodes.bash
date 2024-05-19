#!/bin/bash

num=1
nb_nodes=$1
# waiting for all nodes to be ready
while [ $(echo $nodes | wc -w) -ne $nb_nodes ];
do
	sleep 2
	nodes=$(kubectl get nodes --selector='!node-role.kubernetes.io/control-plane' -o jsonpath='{range .items[*].status.addresses[?(@.type=="InternalIP")]}{.address} {end}')
	echo $nodes
done

for n in $nodes;
do       
	echo "" >> /home/ubuntu/.ssh/config;
	echo "Host node"$num >> /home/ubuntu/.ssh/config;
	echo "        HostName "$n >> /home/ubuntu/.ssh/config;
	echo "        User ubuntu" >> /home/ubuntu/.ssh/config; 
	num=$((num + 1))
done
