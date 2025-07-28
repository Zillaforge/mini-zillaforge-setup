#!/bin/bash

set -e

sudo apt update
curl -sfL https://get.k3s.io | sh -
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> ~/.bashrc
echo 'source <(kubectl completion bash)' >> ~/.bashrc
source ~/.bashrc

####
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
sudo chmod 700 get_helm.sh
./get_helm.sh
source ~/.bashrc

###
sudo apt  install jq -y

###
TAR_DIR="/tmp"

for f in "$TAR_DIR"/*.tar; do
  echo "Importing $f ..."
  sudo ctr --address /run/k3s/containerd/containerd.sock -n k8s.io images import "$f"
done

echo "Adding annotation..."

sudo ctr --address /run/k3s/containerd/containerd.sock -n k8s.io images ls -q | while read -r img; do
  echo "Labeling $img ..."
  sudo ctr --address /run/k3s/containerd/containerd.sock -n k8s.io image label "$img" io.cri-containerd.image=managed
done

echo "Done"