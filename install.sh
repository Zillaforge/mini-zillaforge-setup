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

# Configure and install VPS and VRM services
echo "⚙️ Configuring VPS and VRM services..."

# Check if OpenStack is available and get keystone URL
if command -v openstack &> /dev/null && [ -f "/etc/kolla/clouds.yaml" ]; then
    echo "🔧 OpenStack detected, configuring keystone integration..."
    source /home/ubuntu/venv/bin/activate 2>/dev/null || true
    export OS_CLIENT_CONFIG_FILE=/etc/kolla/clouds.yaml
    export OS_CLOUD=kolla-admin
    
    # Get keystone URL for VPS and VRM configuration
    KEYSTONE_URL=$(openstack endpoint list --service identity --interface public -f value -c URL 2>/dev/null || echo "http://localhost:5000/v3")
    echo "Keystone URL: $KEYSTONE_URL"
    
    # Update VPS configuration
    sed -i "s#keystone_url#$KEYSTONE_URL#g" ./helm/vps/config/trustedcloud.yaml
    
    # Update VRM configuration
    sed -i "s#keystone_url#$KEYSTONE_URL#g" ./helm/vrm/values-trustedcloud.yaml
    
    deactivate 2>/dev/null || true
else
    echo "⚠️ OpenStack not detected, using default keystone URL..."
    sed -i "s#keystone_url#http://localhost:5000/v3#g" ./helm/vps/config/trustedcloud.yaml
    sed -i "s#keystone_url#http://localhost:5000/v3#g" ./helm/vrm/values-trustedcloud.yaml
fi

# Install VRM (Virtual Resource Manager)
echo "🔧 Installing VRM..."
helm install vrm ./helm/vrm -f ./helm/vrm/values-trustedcloud.yaml

# Install VPS (Virtual Platform Service)
echo "🔧 Installing VPS..."
helm install vps ./helm/vps -f ./helm/vps/values-trustedcloud.yaml

echo "✅ VRM and VPS installed"

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

echo "=========================================="
echo "Zillaforge Installation completed successfully!"
echo "All services including VPS and VRM have been installed!"
echo "Next step: Run './post-configuration.sh' to complete OpenStack integration"
echo "=========================================="
