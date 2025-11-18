#!/bin/bash

sudo chmod +r /etc/rancher/k3s/k3s.yaml
POD=$(kubectl get pod | grep user-portal-public-deployment | awk '{print $1}' | head -n 1)
kubectl exec -it "$POD" -c user-portal-public -- sh -c "sed -i '/Content-Security-Policy/d' /etc/nginx/nginx.conf && nginx -s reload"