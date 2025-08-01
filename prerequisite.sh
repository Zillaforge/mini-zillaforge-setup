#!/bin/bash

# Prerequisite script - Install required tools, images, and prepare environment
set -e

echo "=========================================="
echo "Running Prerequisites Setup"
echo "=========================================="


# Update system packages
echo "📦 Updating system packages..."
sudo apt update

# Install required packages
echo "📦 Installing required packages..."
sudo apt install make jq -y



# Install Docker from Official Site
echo "🐳 Installing Docker..."

for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done

# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo usermod -aG docker $USER
# sudo newgrp docker

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
repos=("ldapservice" "pegasusiam" "virtualregistrymanagement" "virtualplatformservice" "cloudstorage" "kongauthplugin" "eventpublishplugin" "kongresponsetransformerplugin" "adminpanel" "userportal")

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

# Create required directories
echo "📁 Creating required directories..."
sudo mkdir -p /trusted-cloud/normal/services/backup/postgres-backup
sudo mkdir -p /trusted-cloud/local/postgres-ha/postgres
sudo mkdir -p /trusted-cloud/local/redis
sudo mkdir -p /trusted-cloud/normal/site-storage
sudo mkdir -p /trusted-cloud/normal/storage
sudo mkdir -p /trusted-cloud/sensitivity/storage
sudo chmod -R 775 /trusted-cloud

echo "✅ Directories created"

# # Add OpenStack users (if OpenStack is available)
# echo "👤 Adding OpenStack users (if available)..."
# if command -v openstack &> /dev/null && [ -f "/etc/kolla/clouds.yaml" ] && [ -f "/home/ubuntu/venv/bin/activate" ]; then
#     echo "🔧 OpenStack detected, adding users..."
    
#     # Activate OpenStack environment
#     source /home/ubuntu/venv/bin/activate
#     export OS_CLIENT_CONFIG_FILE=/etc/kolla/clouds.yaml
#     export OS_CLOUD=kolla-admin
    
#     # OpenStack user configuration parameters
#     USER_NAME="test@trusted-cloud.nchc.org.tw"
#     PROJECT_NAME="trustedcloud"
#     DOMAIN_NAME="trustedcloud"
#     ROLE_NAME="admin"

#     echo "🔎 Getting User UUID..."
#     USER_ID=$(openstack user list --domain "$DOMAIN_NAME" -f value -c ID -c Name | grep "$USER_NAME" | awk '{print $1}')

#     if [ -z "$USER_ID" ]; then
#         echo "❌ Cannot find user: $USER_NAME in domain: $DOMAIN_NAME"
#     else
#         echo "✅ User ID: $USER_ID"

#         echo "🔎 Getting Project UUID..."
#         PROJECT_ID=$(openstack project list -f value -c ID -c Name | grep "$PROJECT_NAME" | awk '{print $1}')

#         if [ -z "$PROJECT_ID" ]; then
#             echo "❌ Cannot find project: $PROJECT_NAME"
#         else
#             echo "✅ Project ID: $PROJECT_ID"

#             echo "⚙️ Adding Project Role..."
#             openstack role add --project "$PROJECT_ID" --user "$USER_ID" "$ROLE_NAME" 2>/dev/null || echo "Project role may already exist"

#             echo "⚙️ Adding System Role..."
#             openstack role add --user "$USER_ID" --system all "$ROLE_NAME" 2>/dev/null || echo "System role may already exist"

#             echo "⚙️ Adding Domain Role..."
#             openstack role add --user "$USER_ID" --domain "$DOMAIN_NAME" "$ROLE_NAME" 2>/dev/null || echo "Domain role may already exist"

#             echo "🎉 All roles have been successfully added!"
#         fi
#     fi
    
#     deactivate
#     echo "✅ OpenStack user configuration completed"
# else
#     echo "⚠️ OpenStack not available, skipping user addition"
# fi

echo "=========================================="
echo "Prerequisites setup completed successfully!"
echo "Please run 'source ~/.bashrc' or restart your terminal"
echo "=========================================="
