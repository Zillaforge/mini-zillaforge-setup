#!/bin/bash

# Script to clone utility-image-builder and build specific images
set -e

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run as root (use sudo)" 
   echo "Usage: sudo $0"
   exit 1
fi

echo "Cloning utility-image-builder repository to /tmp..."
cd /tmp
git clone https://github.com/Zillaforge/utility-image-builder

echo "Changing to utility-image-builder directory..."
cd utility-image-builder

echo "Building debugger image..."
make release-image-debugger

echo "Building golang image..."
make release-image-golang

echo "Utility image builder completed successfully!"

# Clean up utility-image-builder
echo "Cleaning up: removing utility-image-builder repository..."
cd /tmp
rm -rf utility-image-builder

# List of repositories to clone and build
repos=(
    "ldapservice"
    "pegasusiam"
    "virtualregistrymanagement"
    "virtualplatformservice"
    "kongauthplugin"
    "eventpublishplugin"
    "kongresponsetransformerplugin"
    "adminpanel"
    "userportal"
)

echo "Starting to build service repositories..."

# Loop through each repository
for repo in "${repos[@]}"; do
    echo "Processing repository: $repo"
    
    echo "Cloning $repo repository to /tmp..."
    cd /tmp
    git clone "https://github.com/Zillaforge/$repo"
    
    echo "Changing to $repo directory..."
    cd "$repo"
    
    # Check if this is adminpanel or userportal for special build command
    if [[ "$repo" == "adminpanel" || "$repo" == "userportal" ]]; then
        echo "Building $repo image with release-image-public..."
        make release-image-public
    else
        echo "Building $repo image with RELEASE_MODE=prod..."
        make RELEASE_MODE=prod release-image
    fi
    
    echo "$repo build completed!"
    
    # Clean up - delete the cloned repository
    echo "Cleaning up: removing $repo repository..."
    cd /tmp
    rm -rf "$repo"
    
    echo "----------------------------------------"
done

echo "All builds completed successfully!"


# Clean up base images
echo "Cleaning up base images..."

# List of base images to remove
base_images=("kong-plugin-base" "ubuntu" "nginx" "alpine" "busybox" "node")

# Loop through each base image and remove their tags
for image in "${base_images[@]}"; do
    echo "Removing tags for $image images..."
    # Get all image:tag combinations and remove tags
    docker images --format "table {{.Repository}}:{{.Tag}}" | grep "^$image:" | while read image_tag; do
        if [[ "$image_tag" != "$image:<none>" ]]; then
            docker rmi "$image_tag" 2>/dev/null || echo "Could not remove tag: $image_tag"
        fi
    done 2>/dev/null || echo "No $image images to untag"
done

# Remove dangling images
echo "Removing dangling images..."
docker image prune -f 2>/dev/null || echo "No dangling images to remove"

echo "Base image cleanup completed!"
echo "Script execution finished!"


# Save Zillaforge images as tar files
echo "Saving Zillaforge images as tar files..."
cd /tmp

# Get all Zillaforge images except golang and save them as tar files
docker images --format "{{.Repository}}:{{.Tag}}" | grep "^Zillaforge/" | grep -v "Zillaforge/golang" | while read image_tag; do
    # Extract repository and tag for filename
    repo_name=$(echo "$image_tag" | cut -d'/' -f2 | cut -d':' -f1)
    tag_name=$(echo "$image_tag" | cut -d':' -f2)
    
    # Create filename with repository and tag
    filename="${repo_name}_${tag_name}.tar"
    
    echo "Saving $image_tag as $filename..."
    docker save -o "$filename" "$image_tag"
    
    if [[ $? -eq 0 ]]; then
        echo "Successfully saved $image_tag to $filename"
    else
        echo "Failed to save $image_tag"
    fi
done

echo "Image saving completed!"