#!/bin/bash

# Installation script - Install all Helm charts
# set -e

echo "=========================================="
echo "Running Zillaforge Installation"
echo "=========================================="

# Create required directories
echo "📁 Creating required directories..."
sudo mkdir -p /trusted-cloud/normal/services/backup/postgres-backup
sudo mkdir -p /trusted-cloud/local/postgres-ha/postgres
sudo mkdir -p /trusted-cloud/local/redis
sudo mkdir -p /trusted-cloud/normal/site-storage
sudo mkdir -p /trusted-cloud/normal/storage
sudo mkdir -p /trusted-cloud/sensitivity/storage
sudo mkdir -p /trusted-cloud/sensitivity/release
sudo mkdir -p /trusted-cloud/sensitivity/exchange_public
sudo mkdir -p /trusted-cloud/normal/services/harbor/registry
sudo mkdir -p /trusted-cloud/normal/services/harbor/harbor-jobservice

sudo chmod -R 775 /trusted-cloud

echo "✅ Directories created"

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
sed -i "s/instance-hx9bq8/$HOSTNAME/g" ./helm/harbor/values-trustedcloud.yaml

# Update configuration files with IP
echo "📝 Updating configuration files with IP..."
sed -i "s/hostip/$HOSTIP_DASH/g" ./helm/ingress/admin.yaml
sed -i "s/hostip/$HOSTIP_DASH/g" ./helm/ingress/ingress_kong.yaml
sed -i "s/hostip/$HOSTIP_DASH/g" ./helm/ingress/www.yaml
sed -i "s/hostip/$HOSTIP_DASH/g" ./helm/ingress/user.yaml
sed -i "s/hostip/$HOSTIP_DASH/g" ./helm/ingress/kibana-ingress.yaml
sed -i "s/hostip/$HOSTIP_DASH/g" ./helm/portal/values-user-portal-public.yaml
sed -i "s/hostip/$HOSTIP_DASH/g" ./helm/portal/values-admin-panel-public.yaml
sed -i "s/hostip/$HOSTIP_DASH/g" ./helm/ingress/ssscloudstorage.yaml
sed -i "s/hostip/$HOSTIP_DASH/g" ./helm/ingress/cloudstorage.yaml
sed -i "s/hostip/$HOSTIP_DASH/g" ./helm/cloud-storage/values-dss-public.yaml
sed -i "s/hostip/$HOSTIP_DASH/g" ./helm/ingress/dataexchange.yaml
sed -i "s/hostip/$HOSTIP_DASH/g" ./helm/cloud-storage/values-des-cs-rw.yaml
sed -i "s/hostip/$HOSTIP_DASH/g" ./helm/container-registry-management/values-crm-rw-proxy.yaml
sed -i "s/hostip/$HOSTIP_DASH/g" ./helm/container-registry-management/values.yaml
sed -i "s/hostip/$HOSTIP_DASH/g" ./helm/harbor/values-trustedcloud.yaml
sed -i "s/hostip/$HOSTIP_DASH/g" ./helm/ingress/crm.yaml
sed -i "s/hostip/$HOSTIP_DASH/g" ./helm/ingress/harborportal.yaml

echo "✅ Configuration files updated"

echo "📝 Patching Traefik service to use specific NodePort to avoid conflicts..."

kubectl patch service traefik -n kube-system \
  --type='json' \
  -p='[
    {"op":"replace","path":"/spec/ports/0/nodePort","value":31111},
    {"op":"replace","path":"/spec/ports/1/nodePort","value":32222}
  ]'

echo "✅ Traefik service patched with NodePort 31111 and 32222"

# Install Slurm Cluster
echo "Install Slurm cluster..."
sudo apparmor_parser -R  /etc/apparmor.d/unix-chkpwd
# generate SSH key under ubuntu user
rm -f ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -q
helm install slurm ./helm/slurm -f ./helm/slurm/values-trustedcloud.yaml --set secrets.sshPublicKey="$(cat $HOME/.ssh/id_ed25519.pub)"
echo "waiting for Slurm cluster to be ready..."
kubectl -n=slurm wait --for=condition=available deployment/slurmrestd --timeout=1200s

# Install message queue
echo "🐰 Installing RabbitMQ..."
helm install rabbitmq oci://registry-1.docker.io/bitnamicharts/rabbitmq -f ./helm/rabbit_values.yaml --set image.repository=bitnamilegacy/rabbitmq --set global.security.allowInsecureImages=true

echo "✅ RabbitMQ installed"

# Install databases
echo "🗄️ Installing databases..."

echo "Installing PostgreSQL..."
helm install test-postgresql ./helm/postgresql -f ./helm/postgresql/values-trustedcloud.yaml

echo "Installing Redis Sentinel..."
helm install test-redis ./helm/redis-sentinel -f ./helm/redis-sentinel/values-trustedcloud.yaml

echo "Installing MariaDB Galera..."
helm install test-mariadb ./helm/mariadb-galera -f ./helm/mariadb-galera/values-trustedcloud.yaml

echo "waiting for MariaDB Galera statefulset to be ready..."
kubectl rollout status statefulset/mariadb-galera

echo "✅ Databases installed"

#Install elastsearch
echo "Installing ECK Operator..."
kubectl create -f https://download.elastic.co/downloads/eck/3.2.0/crds.yaml
kubectl apply -f https://download.elastic.co/downloads/eck/3.2.0/operator.yaml
echo "Waiting for ECK Operator to be ready..."
kubectl rollout status deployment/elastic-operator -n elastic-system

#kibana+elastic
helm repo add elastic https://helm.elastic.co
helm repo update
echo "install kibana and elastic ..."
helm install es-kb-quickstart elastic/eck-stack --wait --timeout 5m

#修改一些東西(kibana+elastic的設定)
echo "Applying Elasticsearch configuration..."
kubectl apply -f ./helm/reconfigure_elasticsearch.yaml
echo "Waiting for Elasticsearch pods to be ready..."
kubectl rollout status statefulset/elasticsearch-master
echo "Elasticsearch configuration complete."

#Install filebeats

# echo "Installing filebea..."
# helm install filebeat ./helm/filebeat-kubernetes -f ./helm/filebeat-kubernetes/values-openstack.yaml

# Install core services
echo "🔐 Installing core services..."

echo "Creating service account for PegasusIAM..."
kubectl create serviceaccount pegasus-system-admin

echo "Installing PegasusIAM..."
helm install pegasusiam ./helm/pegasusiam -f ./helm/pegasusiam/values-trustedcloud.yaml

echo "waiting for IAM deployments to be ready..."
kubectl wait --for=condition=available deployment/iam-deployment --timeout=1200s

echo "Installing LDAP OpenStack integration..."
helm install ldap-opsk ./helm/ldap -f ./helm/ldap/values-openstack.yaml
helm install ldap-iam ./helm/ldap -f ./helm/ldap/values-iam.yaml

echo "waiting for LDAP deployments to be ready..."
kubectl wait --for=condition=available deployment/ldap-service-openstack-deployment --timeout=1200s

echo "Installing System Kong (API Gateway)..."
helm install systemkong ./helm/system-kong -f ./helm/system-kong/values-public.yaml

echo "✅ Core services installed"

echo "Installing audit-track-service..."
helm install ats ./helm/audit-track-service -f ./helm/audit-track-service/values-core.yaml

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

# Add OpenStack users (if OpenStack is available)

echo "👤 Adding OpenStack users (if available)..."
source /home/ubuntu/venv/bin/activate

if command -v openstack &>/dev/null && [ -f "/etc/kolla/clouds.yaml" ]; then
	echo "🔧 OpenStack detected, adding users..."

	# Activate OpenStack environment
	export OS_CLIENT_CONFIG_FILE=/etc/kolla/clouds.yaml
	export OS_CLOUD=kolla-admin

	# OpenStack user configuration parameters
	USER_NAME="test@trusted-cloud.nchc.org.tw"
	PROJECT_NAME="trustedcloud"
	DOMAIN_NAME="trustedcloud"
	ROLE_NAME="admin"

	container_name="keystone"

	echo "create domain $DOMAIN_NAME and project $PROJECT_NAME"
	openstack domain create $DOMAIN_NAME
	openstack project create $PROJECT_NAME --domain $DOMAIN_NAME

	echo "restart keystone container"
	sudo docker restart $container_name

	echo "restart memcached container"
	sudo docker restart memcached

	# Wait for container to report healthy
	echo "Waiting for $container_name to become healthy..."
	while [ "$(sudo docker inspect --format='{{.State.Health.Status}}' $container_name 2>/dev/null)" != "healthy" ]; do
		sleep 2
		status=$(sudo docker inspect --format='{{.State.Health.Status}}' $container_name 2>/dev/null)
		echo "Current status: $status"
		if [ "$status" == "unhealthy" ]; then
			echo "$container_name is unhealthy. Exiting."
		fi
	done

	echo "🔎 Getting User UUID..."
	USER_ID=$(openstack user list --domain "$DOMAIN_NAME" -f value -c ID -c Name | grep "$USER_NAME" | awk '{print $1}')

	if [ -z "$USER_ID" ]; then
		echo "❌ Cannot find user: $USER_NAME in domain: $DOMAIN_NAME"
		exit 1
	else
		echo "✅ User ID: $USER_ID"

		echo "🔎 Getting Project UUID..."
		PROJECT_ID=$(openstack project list -f value -c ID -c Name | grep "$PROJECT_NAME" | awk '{print $1}')

		if [ -z "$PROJECT_ID" ]; then
			echo "❌ Cannot find project: $PROJECT_NAME"
			exit 1
		else
			echo "✅ Project ID: $PROJECT_ID"

			echo "⚙️ Adding Project Role..."
			openstack role add --user "$USER_ID" --project "$PROJECT_ID" "$ROLE_NAME" 2>/dev/null || echo "Project role may already exist"

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
if command -v openstack &>/dev/null && [ -f "/etc/kolla/clouds.yaml" ]; then
	echo "🔧 OpenStack detected, configuring keystone integration..."
	export OS_CLIENT_CONFIG_FILE=/etc/kolla/clouds.yaml
	export OS_CLOUD=kolla-admin

	# Get keystone URL for VPS and VRM configuration
	KEYSTONE_URL=$(openstack endpoint list --service identity --interface public -f value -c URL)
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

echo "waiting for VRM deployments to be ready..."
kubectl wait --for=condition=available deployment/virtual-registry-management-core-deployment --timeout=1200s

# Install VPS (Virtual Platform Service)
echo "🔧 Installing VPS..."
helm install vps ./helm/vps -f ./helm/vps/values-trustedcloud.yaml

echo "waiting for VPS deployments to be ready..."
kubectl wait --for=condition=available deployment/vps-server --timeout=1200s

echo "✅ VRM and VPS installed"

#cloud-storage
helm install cloudstorage ./helm/cloud-storage/ -f ./helm/cloud-storage/values-dss-public.yaml

#site-cloud-storage
helm install sss ./helm/cloud-storage/ -f ./helm/cloud-storage/values-site-storage.yaml

echo "waiting for CS-public deployments to be ready..."
kubectl wait --for=condition=available deployment/data-storage-service-public-core-deployment --timeout=1200s

echo "waiting for CS-system deployments to be ready..."
kubectl wait --for=condition=available deployment/site-storage-service-core-deployment --timeout=1200s

echo "✅ CS installed"

helm install aps ./helm/app-playground-service -f ./helm/app-playground-service/values-trustedcloud.yaml
echo "waiting for APS deployments to be ready..."
kubectl wait --for=condition=available deployment/app-playground-service-core-deployment --timeout=1200s

echo "✅ APS installed"

#MTS

helm install mts ./helm/metering-service -f ./helm/metering-service/values-trustedcloud.yaml 
echo "✅ MTS  installed"

#FS
echo "waiting for File Storage CS-system deployments to be ready..."
helm install desfs ./helm/cloud-storage -f ./helm/cloud-storage/values-des-cs-rw.yaml 
kubectl wait --for=condition=available deployment/data-exchange-service-fs-rw-deployment --timeout=1200s

echo "install File Storage core"
helm install descsrw ./helm/file-storage -f ./helm/file-storage/values-des-fs-rw.yaml
echo "✅ File Storage  installed"

#Harbor
kubectl exec test-postgresql-postgresql-ha-postgresql-0 -- \
  env PGPASSWORD=password \
  psql -h localhost -U postgresqlusername -d postgres \
  -c "CREATE DATABASE forharbor;"
#Create a PostgreSQL database for Harbor.

helm install harbor ./helm/harbor -f ./helm/harbor/values-trustedcloud.yaml 
echo "waiting for Harbor deployments to be ready..."
kubectl wait --for=condition=available deployment/harbor-core --timeout=30s

# 檢查 schema_migrations 是否存在
EXISTS=$(kubectl exec test-postgresql-postgresql-ha-postgresql-0 -- \
  env PGPASSWORD=password \
  psql -h localhost -U postgresqlusername -d forharbor -tAc "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='schema_migrations');")

if [[ "$EXISTS" == "t" ]]; then
    # 檢查是否有 dirty migration
    DIRTY=$(kubectl exec test-postgresql-postgresql-ha-postgresql-0 -- \
      env PGPASSWORD=password \
      psql -h localhost -U postgresqlusername -d forharbor -tAc "SELECT count(*) FROM schema_migrations WHERE dirty = true;")
    
    if [[ "$DIRTY" -gt 0 ]]; then
        echo "修復 dirty migration..."
        kubectl exec test-postgresql-postgresql-ha-postgresql-0 -- \
          env PGPASSWORD=password \
          psql -h localhost -U postgresqlusername -d forharbor -c "UPDATE schema_migrations SET dirty = false WHERE dirty = true;"
    fi
fi
kubectl exec -it redis-0 -- redis-cli -a password SLAVEOF NO ONE
echo "✅ Harbor  installed"

# CRM
echo "waiting for CRM deployments to be ready..."
helm install crm ./helm/container-registry-management -f ./helm/container-registry-management/values-crm-core.yaml 
kubectl wait --for=condition=available deployment/container-registry-management-core-deployment --timeout=1200s
helm install crm-rw ./helm/container-registry-management -f ./helm/container-registry-management/values-crm-rw-proxy.yaml
kubectl wait --for=condition=available deployment/container-registry-management-rw-proxy-deployment --timeout=1200s
echo "✅ CRM  installed"



echo "=========================================="
echo "Zillaforge Installation completed successfully!"
echo "All services including VPS and VRM have been installed!"
echo "Next step: Run './post-configuration.sh' to complete OpenStack integration"
echo "=========================================="
