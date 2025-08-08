#!/bin/bash

# Post-configuration script - Setup OpenStack integration and additional services
set -e

echo "=========================================="
echo "Running Post-Configuration Setup"
echo "=========================================="

# Get IP configuration
HOSTIP=$(curl -s ipinfo.io/ip)
HOSTIP_DASH=$(echo "$HOSTIP" | sed 's/\./-/g')

echo "Host IP: $HOSTIP (dash format: $HOSTIP_DASH)"

# OpenStack configuration
echo "🔧 Configuring OpenStack integration..."

# Activate OpenStack environment
source /home/ubuntu/venv/bin/activate
export OS_CLIENT_CONFIG_FILE=/etc/kolla/clouds.yaml
export OS_CLOUD=kolla-admin

# Update kolla external FQDN for novnc external access
#echo "🔄 Updating kolla external FQDN..."
#sed -i "s/^#\?kolla_external_fqdn: .*/kolla_external_fqdn: \"${HOSTIP_DASH}.nip.io\"/" /etc/kolla/globals.yml
#kolla-ansible reconfig -i ../all-in-one --tags nova

# Create external network (may not always work depending on environment)
echo "🌐 Creating external network..."
set +e  # Don't exit on network creation errors

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

set -e  # Re-enable exit on error

# Download and add Cirros image to OpenStack
# echo "📥 Adding Cirros image to OpenStack..."
# if [ ! -f "cirros-0.6.2-x86_64-disk.img" ]; then
#     wget http://download.cirros-cloud.net/0.6.2/cirros-0.6.2-x86_64-disk.img
# fi

# openstack image create "cirros-0.6.2" \
#   --file cirros-0.6.2-x86_64-disk.img \
#   --disk-format qcow2 \
#   --container-format bare \
#   --public

# openstack image set --property defaultUser=user --property distribution=cirros cirros-0.6.2

# Get OpenStack project and image IDs for service configuration
OP_PROJECT_UUID=$(openstack project show trustedcloud -c id -f value)
# OP_IMAGE_ID=$(openstack image show cirros-0.6.2 -c id -f value)

echo "OpenStack Project UUID: $OP_PROJECT_UUID"
# echo "OpenStack Image ID: $OP_IMAGE_ID"

deactivate


#更新kong用的資料庫
kong_pod=$(kubectl get pod | grep public-system-kong | awk '{print $1}' | head -n 1)

kubectl exec -it "$kong_pod" -c system-kong -- sh -c "
  cd /etc/kong && \
  kong config db_import kong.yaml
"
helm delete systemkong
helm install systemkong ./helm/system-kong -f ./helm/system-kong/values-public.yaml


#網址限制
POD=$(kubectl get pod | grep user-portal-public-deployment | awk '{print $1}' | head -n 1)
kubectl exec -it "$POD" -c user-portal-public -- sh -c "sed -i '/Content-Security-Policy/d' /etc/nginx/nginx.conf && nginx -s reload"


echo "waiting for KONG deployments to be ready..."
kubectl wait --for=condition=available deployment/public-system-kong --timeout=1200s


# Configure IAM and VRM integration
echo "🔗 Configuring IAM and VRM integration..."


# Wait for IAM API to be ready (HTTP 200), with binary backoff, max 5 tries
echo $HOSTIP_DASH
IAM_API_URL="http://kong.$HOSTIP_DASH.nip.io/iam/api/v1/version"
max_retries=5
wait_time=1
retry=0
while [ $retry -lt $max_retries ]; do
  status=$(curl -s -o /dev/null -w "%{http_code}" "$IAM_API_URL")
  if [ "$status" = "200" ]; then
    echo "IAM API is ready (HTTP 200)"
    break
  fi
  retry=$((retry+1))
  if [ $retry -eq $max_retries ]; then
    echo "❌ IAM API not ready after $max_retries attempts. Exiting."
    exit 1
  fi
  echo "IAM API not ready (status: $status), retry $retry/$max_retries, waiting $wait_time seconds..."
  sleep $wait_time
  wait_time=$((wait_time*2))
done

# Get IAM token
TOKEN=$(curl -s --request POST \
  --url http://kong.$HOSTIP_DASH.nip.io/iam/api/v1/admin/login \
  --header 'Content-Type: application/json' \
  --header 'User-Agent: insomnia/11.2.0' \
  --data '{
  "account": "admin@ci.asus.com",
  "password": "admin"
}' | jq -r '.token')

echo "IAM Token obtained"

# Get IAM project UUID and user ID
IAM_PROJECT_UUID=$(curl -X GET "http://kong.$HOSTIP_DASH.nip.io/iam/api/v1/admin/user?limit=20" -H "accept: application/json" -H "Authorization: Bearer $TOKEN" | jq -r '.permission.projectId')
USER_ID=$(curl -X GET "http://kong.$HOSTIP_DASH.nip.io/iam/api/v1/admin/user?limit=20" -H "accept: application/json" -H "Authorization: Bearer $TOKEN" | jq -r '.userId')

echo "IAM Project UUID: $IAM_PROJECT_UUID"
echo "User ID: $USER_ID"

# Update user membership
curl --request PUT \
  --url "http://kong.$HOSTIP_DASH.nip.io/iam/api/v1/admin/membership/project/$IAM_PROJECT_UUID/user/$USER_ID" \
  --header "Authorization: Bearer $TOKEN" \
  --header 'Content-Type: application/json' \
  --header 'User-Agent: insomnia/11.2.0' \
  --data '{
    "extra": {
        "opUserMode": 3
    }
}'

echo ""

# Update project configuration
curl -X 'PUT' \
  "http://kong.$HOSTIP_DASH.nip.io/iam/api/v1/admin/project/$IAM_PROJECT_UUID" \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d @- <<EOF
{
  "extra": {
    "iservice": {
      "projectSysCode": "trustedcloud"
    },
    "tw-tc-ad1": {
      "opsk": {
        "uuid": "$OP_PROJECT_UUID"
      }
    }
  }
}
EOF

# Import Cirros image to VRM
# curl -X 'POST' \
#   "http://kong.$HOSTIP_DASH.nip.io/vrm/api/v1/admin/import" \
#   -H 'accept: application/json' \
#   -H "Authorization: Bearer $TOKEN" \
#   -H 'Content-Type: application/json' \
#   -d '{
#   "imageId": "'"$OP_IMAGE_ID"'",
#   "creator": "4990ccdb-a9b1-49e5-91df-67c921601d82",
#   "name": "cirros",
#   "version": "0.6.2",
#   "operatingSystem": "linux",
#   "projectId": "'"$IAM_PROJECT_UUID"'",
#   "namespace": "public"
# }'

echo ""
echo "✅ IAM and VRM integration configured"

echo "=========================================="
echo "Post-Configuration completed successfully!"
echo "System is now ready for use!"
echo ""
echo "Access URLs:"
echo "- User Portal : http://www.$HOSTIP_DASH.nip.io"
echo "- Kong Gateway: http://kong.$HOSTIP_DASH.nip.io"
echo ""
echo "Account & Password:"
echo "admin@ci.asus.com / admin"
echo ""
echo "Download Cirros image: http://download.cirros-cloud.net/0.6.2/cirros-0.6.2-x86_64-disk.img"
echo "Upload image using VRM"
echo "=========================================="
