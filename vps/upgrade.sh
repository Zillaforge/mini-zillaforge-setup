#!/bin/bash

helm -n pegasus-system upgrade virtual-platform-service ./ -f values-trustedcloud.yaml

kubectl -n pegasus-system get configmap vps-config -o yaml

kubectl -n pegasus-system get pod -w |grep vps

