#!/bin/bash

# Installation script - Install all Helm charts
set -e

echo "=========================================="
echo "Running Zillaforge Installation"
echo "=========================================="

# Get hostname and IP for configuration
echo "🔧 Configuring hostname and IP settings..."
HOSTNAME=$(hostname)
HOSTIP=$(curl -s ipinfo.io/ip)
HOSTIP_DASH=$(echo "$HOSTIP" | sed 's/\./-/g')

echo "Hostname: $HOSTNAME"
echo "Host IP: $HOSTIP (dash format: $HOSTIP_DASH)"

# Update configuration files with hostname
echo "📝 Updating configuration files with hostname..."
sed -i "s/instance-hx9bq8/$HOSTNAME/g" ./helm/mariadb-galera/values-trustedcloud.yaml
sed -i "s/instance-hx9bq8/$HOSTNAME/g" ./helm/postgresql/values-trustedcloud.yaml
sed -i "s/instance-hx9bq8/$HOSTNAME/g" ./helm/redis-sentinel/values-trustedcloud.yaml

# Update configuration files with IP
echo "📝 Updating configuration files with IP..."
sed -i "s/hostip/$HOSTIP_DASH/g" ./helm/ingress/admin.yaml
sed -i "s/hostip/$HOSTIP_DASH/g" ./helm/ingress/ingress_kong.yaml
sed -i "s/hostip/$HOSTIP_DASH/g" ./helm/ingress/www.yaml
sed -i "s/hostip/$HOSTIP_DASH/g" ./helm/ingress/user.yaml
sed -i "s/hostip/$HOSTIP_DASH/g" ./helm/portal/values-user-portal-public.yaml
sed -i "s/hostip/$HOSTIP_DASH/g" ./helm/portal/values-admin-panel-public.yaml

echo "✅ Configuration files updated"

# Install databases
echo "🗄️ Installing databases..."

echo "Installing MariaDB Galera..."
helm install test-mariadb ./helm/mariadb-galera -f ./helm/mariadb-galera/values-trustedcloud.yaml

echo "Installing PostgreSQL..."
helm install test-postgresql ./helm/postgresql -f ./helm/postgresql/values-trustedcloud.yaml

echo "Installing Redis Sentinel..."
helm install test-redis ./helm/redis-sentinel -f ./helm/redis-sentinel/values-trustedcloud.yaml

echo "✅ Databases installed"

# Install message queue
echo "🐰 Installing RabbitMQ..."
helm install rabbitmq oci://registry-1.docker.io/bitnamicharts/rabbitmq -f ./helm/rabbit_values.yaml

echo "✅ RabbitMQ installed"

# Install core services
echo "🔐 Installing core services..."

echo "Creating service account for PegasusIAM..."
kubectl create serviceaccount pegasus-system-admin

echo "Installing PegasusIAM..."
helm install pegasusiam ./helm/pegasusiam -f ./helm/pegasusiam/values-trustedcloud.yaml

echo "Installing LDAP OpenStack integration..."
helm install ldap-opsk ./helm/ldap -f ./helm/ldap/values-openstack.yaml

echo "Installing System Kong (API Gateway)..."
helm install systemkong ./helm/system-kong -f ./helm/system-kong/values-public.yaml

echo "✅ Core services installed"

# Install portals
echo "🌐 Installing portals..."

echo "Installing Admin Portal..."
helm install admin-portal ./helm/portal -f ./helm/portal/values-admin-panel-public.yaml

echo "Installing User Portal..."
helm install user-portal ./helm/portal -f ./helm/portal/values-user-portal-public.yaml

echo "✅ Portals installed"

# Apply ingress configuration
echo "🔄 Applying ingress configuration..."
kubectl apply -f ./helm/ingress/

echo "✅ Ingress configuration applied"


echo "waiting for IAM deployments to be ready..."
kubectl wait --for=condition=available deployment/iam-deployment --timeout=1200s

echo "waiting for LDAP deployments to be ready..."
kubectl wait --for=condition=available deployment/ldap-service-openstack-deployment --timeout=1200s





# Add OpenStack users (if OpenStack is available)

echo "👤 Adding OpenStack users (if available)..."
source /home/ubuntu/venv/bin/activate

if command -v openstack &> /dev/null && [ -f "/etc/kolla/clouds.yaml" ]; then
    echo "🔧 OpenStack detected, adding users..."
    
    # Activate OpenStack environment
    export OS_CLIENT_CONFIG_FILE=/etc/kolla/clouds.yaml
    export OS_CLOUD=kolla-admin
    
    # OpenStack user configuration parameters
    USER_NAME="test@trusted-cloud.nchc.org.tw"
    PROJECT_NAME="trustedcloud"
    DOMAIN_NAME="trustedcloud"
    ROLE_NAME="admin"

    echo "🔎 Getting User UUID..."
    USER_ID=$(openstack user list --domain "$DOMAIN_NAME" -f value -c ID -c Name | grep "$USER_NAME" | awk '{print $1}')

    if [ -z "$USER_ID" ]; then
        echo "❌ Cannot find user: $USER_NAME in domain: $DOMAIN_NAME"
    else
        echo "✅ User ID: $USER_ID"

        echo "🔎 Getting Project UUID..."
        PROJECT_ID=$(openstack project list -f value -c ID -c Name | grep "$PROJECT_NAME" | awk '{print $1}')

        if [ -z "$PROJECT_ID" ]; then
            echo "❌ Cannot find project: $PROJECT_NAME"
        else
            echo "✅ Project ID: $PROJECT_ID"

            echo "⚙️ Adding Project Role..."
            openstack role add --project "$PROJECT_ID" --user "$USER_ID" "$ROLE_NAME" 2>/dev/null || echo "Project role may already exist"

            echo "⚙️ Adding System Role..."
            openstack role add --user "$USER_ID" --system all "$ROLE_NAME" 2>/dev/null || echo "System role may already exist"

            echo "⚙️ Adding Domain Role..."
            openstack role add --user "$USER_ID" --domain "$DOMAIN_NAME" "$ROLE_NAME" 2>/dev/null || echo "Domain role may already exist"

            echo "🎉 All roles have been successfully added!"
        fi
    fi
    
    echo "✅ OpenStack user configuration completed"
else
    echo "⚠️ OpenStack not available, EXIT"
    exit 1
fi

deactivate


# Configure and install VPS and VRM services
echo "⚙️ Configuring VPS and VRM services..."

source /home/ubuntu/venv/bin/activate
# Check if OpenStack is available and get keystone URL
if command -v openstack &> /dev/null && [ -f "/etc/kolla/clouds.yaml" ]; then
    echo "🔧 OpenStack detected, configuring keystone integration..."
    export OS_CLIENT_CONFIG_FILE=/etc/kolla/clouds.yaml
    export OS_CLOUD=kolla-admin
    
    # Get keystone URL for VPS and VRM configuration
    KEYSTONE_URL=$(openstack endpoint list --service identity --interface public -f value -c URL 2>/dev/null || echo "http://localhost:5000/v3")
    echo "Keystone URL: $KEYSTONE_URL"
    
    # Update VPS configuration
    sed -i "s#keystone_url#$KEYSTONE_URL#g" ./helm/vps/config/trustedcloud.yaml
    
    # Update VRM configuration
    sed -i "s#keystone_url#$KEYSTONE_URL#g" ./helm/vrm/values-trustedcloud.yaml
    
else
    echo "⚠️ OpenStack not detected, EXIT"
    exit 1
fi
deactivate


# Install VRM (Virtual Resource Manager)
echo "🔧 Installing VRM..."
helm install vrm ./helm/vrm -f ./helm/vrm/values-trustedcloud.yaml

# Install VPS (Virtual Platform Service)
echo "🔧 Installing VPS..."
helm install vps ./helm/vps -f ./helm/vps/values-trustedcloud.yaml


echo "waiting for VRM deployments to be ready..."
kubectl wait --for=condition=available deployment/virtual-registry-management-core-deployment --timeout=1200s

echo "waiting for VPS deployments to be ready..."
kubectl wait --for=condition=available deployment/vps-server --timeout=1200s


echo "✅ VRM and VPS installed"

echo "=========================================="
echo "Zillaforge Installation completed successfully!"
echo "All services including VPS and VRM have been installed!"
echo "Next step: Run './post-configuration.sh' to complete OpenStack integration"
echo "=========================================="
