#!/bin/bash
#更新一下openstack上ldap的連接(暫時先不更新，假如ldap沒有到30891...)

source /home/ubuntu/venv/bin/activate
export OS_CLIENT_CONFIG_FILE=/etc/kolla/clouds.yaml
export OS_CLOUD=kolla-admin
keystone_url=$(openstack endpoint list --service identity --interface public -f value -c URL)
#加openstack上的使用者
#. ~/kolla-ansible/keystone_setup.sh
chmod +x addopuser.sh
./addopuser.sh

#改kolla_external_fqdn，為了novnc能對外
hostip=$(curl -s ipinfo.io/ip)
hostip_dash=$(echo "$hostip" | sed 's/\./-/g')
sed -i "s/^#\?kolla_external_fqdn: .*/kolla_external_fqdn: \"${hostip_dash}.nip.io\"/" /etc/kolla/globals.yml
kolla-ansible reconfig -i ../all-in-one --tags nova

#建立對外網路(不一定能work)
openstack network create ExNet \
  --provider-network-type flat \
  --provider-physical-network physnet1 \
  --external \
  --share

openstack subnet create ExSubnet \
  --network ExNet \
  --subnet-range 192.168.100.0/24 \
  --allocation-pool start=192.168.100.10,end=192.168.100.50 \
  --gateway 192.168.100.1 \
  --no-dhcp


#在openstack中新增cirros 的image
wget http://download.cirros-cloud.net/0.6.2/cirros-0.6.2-x86_64-disk.img
openstack image create "cirros-0.6.2" \
  --file cirros-0.6.2-x86_64-disk.img \
  --disk-format qcow2 \
  --container-format bare \
  --public

openstack image set --property defaultUser=user --property distribution=cirros cirros-0.6.2

deactivate


sed -i "s#keystone_url#$keystone_url#g" ./vps/config/trustedcloud.yaml
sed -i "s#keystone_url#$keystone_url#g" ./vrm/values-trustedcloud.yaml
#vrm
helm install vrm  ./vrm -f ./vrm/values-trustedcloud.yaml

#vps
helm install vps ./vps -f ./vps/values-trustedcloud.yaml

#cloud-storage
helm install cloudstorage ./cloud-storage/ -f ./cloud-storage/values-dss-public.yaml

site-cloud-storage
helm install sss ./cloud-storage/ -f ./cloud-storage/values-site-storage.yaml

#更新kong用的資料庫
kong_pod=$(kubectl get pod | grep public-system-kong | awk '{print $1}' | head -n 1)

kubectl exec -it "$kong_pod" -c system-kong -- sh -c "
  cd /etc/kong && \
  kong config db_import kong.yaml
"
helm delete systemkong
helm install systemkong ./system-kong -f ./system-kong/values-public.yaml 

#網址限制
POD=$(kubectl get pod | grep user-portal-public-deployment | awk '{print $1}' | head -n 1)
kubectl exec -it "$POD" -c user-portal-public -- sh -c "sed -i '/Content-Security-Policy/d' /etc/nginx/nginx.conf && nginx -s reload"
