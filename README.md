# mini-zillaforge-setup

```shell
git clone https://github.com/Zillaforge/mini-zillaforge-setup.git
cd mini-zillaforge-setup

# Prepare image
sudo ./build_images.sh


#Pre-job download k3s, helm...
./prework.sh

#Install
./install.sh
#Confirm that all pods are ready before use
./config.sh
./config2.sh
```