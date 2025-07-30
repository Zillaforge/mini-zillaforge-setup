#!/bin/bash

#補資料庫資訊
export hostip=$(curl -s ipinfo.io/ip)
export hostip_dash=$(echo "$hostip" | sed 's/\./-/g')

export token=$(curl -s --request POST \
  --url http://127.0.0.1:31084/iam/api/v1/admin/login \
  --header 'Content-Type: application/json' \
  --header 'User-Agent: insomnia/11.2.0' \
  --data '{
  "account": "admin@ci.asus.com",
  "password": "admin"
}' | jq -r '.token')


export iam_project_uuid=$(curl -X GET "http://127.0.0.1:31084/iam/api/v1/admin/user?limit=20" -H "accept: application/json" -H "Authorization: Bearer $token" | jq -r '.permission.projectId')
export userid=$(curl -X GET "http://127.0.0.1:31084/iam/api/v1/admin/user?limit=20" -H "accept: application/json" -H "Authorization: Bearer $token" | jq -r '.userId')

curl --request PUT \
  --url "http://kong.$hostip_dash.nip.io/iam/api/v1/admin/membership/project/$iam_project_uuid/user/$userid" \
  --header "Authorization: Bearer $token" \
  --header 'Content-Type: application/json' \
  --header 'User-Agent: insomnia/11.2.0' \
  --data '{
    "extra": {
        "opUserMode": 3
    }
}'

echo " "
source /home/ubuntu/venv/bin/activate
export OS_CLIENT_CONFIG_FILE=/etc/kolla/clouds.yaml
export OS_CLOUD=kolla-admin
export op_project_uuid=$(openstack project show trustedcloud -c id -f value)
export op_imageID=$(openstack image show cirros-0.6.2 -c id -f value)
deactivate


curl -X 'PUT' \
  "http://kong.$hostip_dash.nip.io/iam/api/v1/admin/project/$iam_project_uuid" \
  -H "Authorization: Bearer $token" \
  -H 'Content-Type: application/json' \
  -d @- <<EOF
{
  "extra": {
    "iservice": {
      "projectSysCode": "trustedcloud"
    },
    "tw-tc-ad1": {
      "opsk": {
        "uuid": "$op_project_uuid"
      }
    }
  }
}
EOF

echo " "

curl -X 'POST' \
  "http://kong.$hostip_dash.nip.io/vrm/api/v1/admin/import" \
  -H 'accept: application/json' \
  -H "Authorization: Bearer $token" \
  -H 'Content-Type: application/json' \
  -d '{
  "imageId": "'"$op_imageID"'",
  "creator": "4990ccdb-a9b1-49e5-91df-67c921601d82",
  "name": "cirros",
  "version": "0.6.2",
  "operatingSystem": "linux",
  "projectId": "'"$iam_project_uuid"'",
  "namespace": "public"
}'
echo " "
