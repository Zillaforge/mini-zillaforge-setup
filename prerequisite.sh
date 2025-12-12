#!/bin/bash

# Prerequisite script - Install required tools, images, and prepare environment
set -e

echo "=========================================="
echo "Running Prerequisites Setup"
echo "=========================================="

# 詢問是否使用全自動安裝模式
while true; do
    read -p "Do you want to use fully automatic install prerequisites? (y/n): " answer
    case "$answer" in
        [Yy]* )
            export ENABLE_AUTO_DEPLOY_MODE="true"
            echo -e "${GREEN} Automatic deployment mode enabled. ${ENDCOLOR}"
            break
            ;;
        [Nn]* )
            echo -e "${GREEN} Manual deployment mode selected. ${ENDCOLOR}"
            break
            ;;
        * )
            echo "Invalid input. Please enter 'y' or 'n'."
            ;;
    esac
done


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


# Update system packages
echo "📦 Updating system packages..."
sudo apt update

# Install required packages
echo "📦 Installing required packages..."
sudo apt install make jq -y



# Install Docker from Official Site
echo "🐳 Installing Docker..."
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg

# Install Docker From Docker Official
curl -Ol https://download.docker.com/linux/ubuntu/dists/jammy/pool/stable/amd64/containerd.io_1.7.25-1_amd64.deb
curl -Ol https://download.docker.com/linux/ubuntu/dists/jammy/pool/stable/amd64/docker-ce_27.5.1-1~ubuntu.22.04~jammy_amd64.deb
curl -Ol https://download.docker.com/linux/ubuntu/dists/jammy/pool/stable/amd64/docker-ce-rootless-extras_27.5.1-1~ubuntu.22.04~jammy_amd64.deb
curl -Ol https://download.docker.com/linux/ubuntu/dists/jammy/pool/stable/amd64/docker-ce-cli_27.5.1-1~ubuntu.22.04~jammy_amd64.deb

sudo dpkg -i *.deb
rm *.deb
sudo usermod -aG docker $USER
sudo systemctl start docker
sudo systemctl enable docker
sudo docker version

sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i "s/SystemdCgroup = false/SystemdCgroup = true/g" /etc/containerd/config.toml
grep SystemdCgroup /etc/containerd/config.toml
sudo systemctl restart containerd

# change docker cgroup driver to systemd
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

sudo mkdir -p /etc/systemd/system/docker.service.d
sudo systemctl daemon-reload
sudo systemctl restart docker
systemctl status --no-pager docker



# Essential Tweaks
sudo swapoff -a
cat << EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system
sleep 2

echo "✅ Docker installation completed"

# Install K3s
echo "☸️ Installing K3s..."
curl -sfL https://get.k3s.io | sh -
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> ~/.bashrc
echo 'source <(kubectl completion bash)' >> ~/.bashrc

echo "✅ K3s installation completed"

# Install Helm
echo "⚗️ Installing Helm..."
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
sudo chmod 700 get_helm.sh
./get_helm.sh
rm get_helm.sh

echo "✅ Helm installation completed"

# Build Docker images
echo "🏗️ Building Docker images..."

# Clone and build utility images
echo "Cloning utility-image-builder repository to /tmp..."
cd /tmp
git clone https://github.com/Zillaforge/utility-image-builder

echo "Changing to utility-image-builder directory..."
cd utility-image-builder

echo "Building debugger image..."
sudo make release-image-debugger

echo "Building golang image..."
sudo make release-image-golang

echo "Utility image builder completed successfully!"

# Clean up utility-image-builder
echo "Cleaning up: removing utility-image-builder repository..."
cd /tmp
sudo rm -rf utility-image-builder

# Build service repositories
repos=("ldapservice" "pegasusiam" "virtualregistrymanagement" "virtualplatformservice" "cloudstorage" "appplaygroundservice" "kongauthplugin" "eventpublishplugin" "kongresponsetransformerplugin" "adminpanel" "userportal" "audittrackservice")

echo "Starting to build service repositories..."

for repo in "${repos[@]}"; do
    echo "Processing repository: $repo"
    echo "Cloning $repo repository to /tmp..."
    cd /tmp
    git clone "https://github.com/Zillaforge/$repo"

    echo "Changing to $repo directory..."
    cd "$repo"

    if [[ "$repo" == "adminpanel" || "$repo" == "userportal" ]]; then
        echo "Building $repo image with release-image-public..."
        sudo make release-image-public
    else
        echo "Building $repo image with RELEASE_MODE=prod..."
        sudo make RELEASE_MODE=prod release-image
    fi

    echo "$repo build completed!"
    echo "Cleaning up: removing $repo repository..."
    cd /tmp
    sudo rm -rf "$repo"
    echo "----------------------------------------"
done

echo "All builds completed successfully!"

# Clean up base images
base_images=("kong-plugin-base" "ubuntu" "nginx" "alpine" "busybox" "node")

echo "Cleaning up base images..."

for image in "${base_images[@]}"; do
    echo "Removing tags for $image images..."
    sudo docker images --format "table {{.Repository}}:{{.Tag}}" | grep "^$image:" | while read image_tag; do
        if [[ "$image_tag" != "$image:<none>" ]]; then
            sudo docker rmi "$image_tag" 2>/dev/null || echo "Could not remove tag: $image_tag"
        fi
    done 2>/dev/null || echo "No $image images to untag"
done

echo "Removing dangling images..."
sudo docker image prune -f 2>/dev/null || echo "No dangling images to remove"

echo "Base image cleanup completed!"

# Save Zillaforge images as tar files
echo "💾 Saving Zillaforge images as tar files..."
cd /tmp

sudo docker images --format "{{.Repository}}:{{.Tag}}" | grep "^Zillaforge/" | grep -v "Zillaforge/golang" | while read image_tag; do
    repo_name=$(echo "$image_tag" | cut -d'/' -f2 | cut -d':' -f1)
    tag_name=$(echo "$image_tag" | cut -d':' -f2)
    filename="${repo_name}_${tag_name}.tar"
    echo "Saving $image_tag as $filename..."
    sudo docker save -o "$filename" "$image_tag"
    if [[ $? -eq 0 ]]; then
        echo "Successfully saved $image_tag to $filename"
    else
        echo "Failed to save $image_tag"
    fi
done

echo "✅ Docker images built and saved"

# Import Docker images from tar files
echo "📦 Importing Docker images from /tmp..."
TAR_DIR="/tmp"

if ls "$TAR_DIR"/*.tar 1> /dev/null 2>&1; then
    for f in "$TAR_DIR"/*.tar; do
        echo "Importing $f ..."
        sudo ctr --address /run/k3s/containerd/containerd.sock -n k8s.io images import "$f"
    done

    echo "🏷️ Adding annotations to imported images..."
    sudo ctr --address /run/k3s/containerd/containerd.sock -n k8s.io images ls -q | while read -r img; do
        echo "Labeling $img ..."
        sudo ctr --address /run/k3s/containerd/containerd.sock -n k8s.io image label "$img" io.cri-containerd.image=managed
    done

    echo "✅ Docker images imported and labeled"
else
    echo "⚠️ No tar files found in /tmp - skipping image import"
fi


echo "🔧 Install OpenStack from openstack-deploy submodule..."
# Go back to the script directory
cd "$SCRIPT_DIR"

# Run install.sh inside openstack-deploy submodule folder if it exists
if [ -d "./openstack-deploy" ] && [ -f "./openstack-deploy/install.sh" ]; then
    echo "🚀 Running install.sh in openstack-deploy submodule..."
    (cd ./openstack-deploy && bash install.sh)
    echo "✅ openstack-deploy install.sh completed"
else
    echo "⚠️ openstack-deploy submodule or install.sh not found, skipping."
    echo "Contents of current directory:"
    ls -la
    echo "Please run 'git submodule update --init --recursive' to initialize submodules."
    echo "To install OpenStack, run 'cd openstack-deploy && bash install.sh' manually."
fi

echo "=========================================="
echo "Prerequisites setup completed successfully!"
echo "Please run 'source ~/.bashrc' or restart your terminal"
echo "=========================================="
