#!/bin/bash

set -e

echo "creat DB file...."
sudo mkdir -p /trusted-cloud/normal/services/backup/postgres-backup
sudo mkdir -p /trusted-cloud/local/postgres-ha/postgres
sudo mkdir -p /trusted-cloud/local/redis
sudo mkdir -p /trusted-cloud/normal/site-storage
sudo mkdir -p /trusted-cloud/normal/storage
sudo mkdir -p /trusted-cloud/sensitivity/storage
sudo chmod -R 775 /trusted-cloud
echo "creat DB file....done"

echo "change hostname and hostip...."
aaa=$(hostname)
sed -i "s/instance-hx9bq8/$aaa/g" ./mariadb-galera/values-trustedcloud.yaml
sed -i "s/instance-hx9bq8/$aaa/g" ./postgresql/values-trustedcloud.yaml
sed -i "s/instance-hx9bq8/$aaa/g" ./redis-sentinel/values-trustedcloud.yaml

hostip=$(curl -s ipinfo.io/ip)
hostip_dash=$(echo "$hostip" | sed 's/\./-/g')
sed -i "s/hostip/$hostip_dash/g" ./ingress/admin.yaml
sed -i "s/hostip/$hostip_dash/g" ./ingress/ingress_kong.yaml
sed -i "s/hostip/$hostip_dash/g" ./ingress/www.yaml
sed -i "s/hostip/$hostip_dash/g" ./ingress/user.yaml
sed -i "s/hostip/$hostip_dash/g" ./portal/values-user-portal-public.yaml
sed -i "s/hostip/$hostip_dash/g" ./portal/values-admin-panel-public.yaml
sed -i "s/hostip/$hostip_dash/g" ./ingress/ssscloudstorage.yaml
sed -i "s/hostip/$hostip_dash/g" ./ingress/cloudstorage.yaml
sed -i "s/hostip/$hostip_dash/g" ./cloud-storage/values-dss-public.yaml


echo "change hostname and hostip....done"

#test-mariadb
helm install test-mariadb ./mariadb-galera -f ./mariadb-galera/values-trustedcloud.yaml

#test-postgresql
helm install test-postgresql ./postgresql -f ./postgresql/values-trustedcloud.yaml

#test-redis
helm install test-redis ./redis-sentinel -f ./redis-sentinel/values-trustedcloud.yaml

#rabbitmq
helm install rabbitmq oci://registry-1.docker.io/bitnamicharts/rabbitmq -f rabbit_values.yaml 

#pegasusiam
kubectl create serviceaccount pegasus-system-admin
helm install pegasusiam ./pegasusiam -f ./pegasusiam/values-trustedcloud.yaml

#ldap-opsk
helm install ldap-opsk ./ldap -f ldap/values-openstack.yaml

#systemkong
helm install systemkong ./system-kong -f ./system-kong/values-public.yaml

#admin-portal
helm install admin-portal ./portal -f ./portal/values-admin-panel-public.yaml

#user-portal
helm install user-portal ./portal -f ./portal/values-user-portal-public.yaml

#ingress
kubectl apply -f ./ingress/
