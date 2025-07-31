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

# Get keystone URL for VPS and VRM configuration
KEYSTONE_URL=$(openstack endpoint list --service identity --interface public -f value -c URL)
echo "Keystone URL: $KEYSTONE_URL"

# Update kolla external FQDN for novnc external access
echo "🔄 Updating kolla external FQDN..."
sed -i "s/^#\?kolla_external_fqdn: .*/kolla_external_fqdn: \"${HOSTIP_DASH}.nip.io\"/" /etc/kolla/globals.yml
kolla-ansible reconfig -i ../all-in-one --tags nova

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
echo "📥 Adding Cirros image to OpenStack..."
if [ ! -f "cirros-0.6.2-x86_64-disk.img" ]; then
    wget http://download.cirros-cloud.net/0.6.2/cirros-0.6.2-x86_64-disk.img
fi

openstack image create "cirros-0.6.2" \
  --file cirros-0.6.2-x86_64-disk.img \
  --disk-format qcow2 \
  --container-format bare \
  --public

openstack image set --property defaultUser=user --property distribution=cirros cirros-0.6.2

# Get OpenStack project and image IDs for service configuration
OP_PROJECT_UUID=$(openstack project show trustedcloud -c id -f value)
OP_IMAGE_ID=$(openstack image show cirros-0.6.2 -c id -f value)

echo "OpenStack Project UUID: $OP_PROJECT_UUID"
echo "OpenStack Image ID: $OP_IMAGE_ID"

deactivate

# Configure IAM and VRM integration
echo "🔗 Configuring IAM and VRM integration..."

# Get IAM token
TOKEN=$(curl -s --request POST \
  --url http://127.0.0.1:31084/iam/api/v1/admin/login \
  --header 'Content-Type: application/json' \
  --header 'User-Agent: insomnia/11.2.0' \
  --data '{
  "account": "admin@ci.asus.com",
  "password": "admin"
}' | jq -r '.token')

echo "IAM Token obtained"

# Get IAM project UUID and user ID
IAM_PROJECT_UUID=$(curl -X GET "http://127.0.0.1:31084/iam/api/v1/admin/user?limit=20" -H "accept: application/json" -H "Authorization: Bearer $TOKEN" | jq -r '.permission.projectId')
USER_ID=$(curl -X GET "http://127.0.0.1:31084/iam/api/v1/admin/user?limit=20" -H "accept: application/json" -H "Authorization: Bearer $TOKEN" | jq -r '.userId')

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
curl -X 'POST' \
  "http://kong.$HOSTIP_DASH.nip.io/vrm/api/v1/admin/import" \
  -H 'accept: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
  "imageId": "'"$OP_IMAGE_ID"'",
  "creator": "4990ccdb-a9b1-49e5-91df-67c921601d82",
  "name": "cirros",
  "version": "0.6.2",
  "operatingSystem": "linux",
  "projectId": "'"$IAM_PROJECT_UUID"'",
  "namespace": "public"
}'

echo "✅ IAM and VRM integration configured"

echo "=========================================="
echo "Post-Configuration completed successfully!"
echo "System is now ready for use!"
echo ""
echo "Access URLs:"
echo "- Admin Portal: http://admin.$HOSTIP_DASH.nip.io"
echo "- User Portal: http://user.$HOSTIP_DASH.nip.io"
echo "- Kong Gateway: http://kong.$HOSTIP_DASH.nip.io"
echo "=========================================="
