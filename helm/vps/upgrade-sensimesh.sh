#!/bin/bash

helm -n sensimesh-system upgrade virtual-platform-service ./ -f values-sensimesh.yaml

kubectl -n sensimesh-system get configmap vps-config -o yaml

kubectl -n sensimesh-system get pod -w |grep vps

