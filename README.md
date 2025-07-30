# mini-zillaforge-setup

```shell
git clone https://github.com/Zillaforge/mini-zillaforge-setup.git
cd mini-zillaforge-setup

# Install require package
sudo ./install_packages.sh


# Prepare image
sudo ./build_images.sh

# Install k3s & Helm, Then import built image 
sudo ./prework.sh
```