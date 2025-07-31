#!/bin/bash
VER=$1
if [ -z $VER ]; then
  echo "version required"
  exit 1
fi

set -e

docker login -u Zillaforge --password-stdin <<< 2266c204-b41a-4b95-b45f-55bf01a12033
docker pull Zillaforge/virtual-platform-service:$VER
docker logout
docker tag Zillaforge/virtual-platform-service:$VER 10.247.4.4:80/trusted-cloud/virtual-platform-service:$VER
docker push 10.247.4.4:80/trusted-cloud/virtual-platform-service:$VER
docker rmi 10.247.4.4:80/trusted-cloud/virtual-platform-service:$VER
docker rmi Zillaforge/virtual-platform-service:$VER
