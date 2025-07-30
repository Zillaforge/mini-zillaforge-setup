# 需要設定的參數
USER_NAME="test@trusted-cloud.nchc.org.tw"
PROJECT_NAME="trustedcloud"
DOMAIN_NAME="trustedcloud"
ROLE_NAME="admin"

echo "🔎 取得 User UUID..."
USER_ID=$(openstack user list --domain "$DOMAIN_NAME" -f value -c ID -c Name | grep "$USER_NAME" | awk '{print $1}')

if [ -z "$USER_ID" ]; then
    echo "❌ 找不到 user: $USER_NAME in domain: $DOMAIN_NAME"
    exit 1
fi
echo "✅ User ID: $USER_ID"

echo "🔎 取得 Project UUID..."
PROJECT_ID=$(openstack project list -f value -c ID -c Name | grep "$PROJECT_NAME" | awk '{print $1}')

if [ -z "$PROJECT_ID" ]; then
    echo "❌ 找不到 project: $PROJECT_NAME"
    exit 1
fi
echo "✅ Project ID: $PROJECT_ID"

echo "⚙️  加入 Project Role..."
openstack role add --project "$PROJECT_ID" --user "$USER_ID" "$ROLE_NAME"

echo "⚙️  加入 System Role..."
openstack role add --user "$USER_ID" --system all "$ROLE_NAME"

echo "⚙️  加入 Domain Role..."
openstack role add --user "$USER_ID" --domain "$DOMAIN_NAME" "$ROLE_NAME"

echo "🎉 所有角色已成功加入完成！"
