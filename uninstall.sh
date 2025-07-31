#!/bin/bash

# Uninstall script - Remove all Helm charts and related resources
set -e

echo "=========================================="
echo "Running Zillaforge Uninstallation"
echo "=========================================="

echo "⚠️  WARNING: This will remove all Zillaforge services and data!"
echo "Press Ctrl+C to cancel, or wait 10 seconds to continue..."
sleep 10

# Remove VRM and VPS services
echo "🗑️ Removing VRM and VPS services..."
set +e  # Don't exit if helm delete fails (chart might not exist)

helm delete vrm 2>/dev/null || echo "VRM not found or already removed"
helm delete vps 2>/dev/null || echo "VPS not found or already removed"

echo "✅ VRM and VPS services removed"

# Remove portals
echo "🗑️ Removing portals..."
helm delete admin-portal 2>/dev/null || echo "Admin portal not found or already removed"
helm delete user-portal 2>/dev/null || echo "User portal not found or already removed"

echo "✅ Portals removed"

# Remove core services
echo "🗑️ Removing core services..."
helm delete systemkong 2>/dev/null || echo "System Kong not found or already removed"
helm delete ldap-opsk 2>/dev/null || echo "LDAP OpenStack not found or already removed"
helm delete pegasusiam 2>/dev/null || echo "PegasusIAM not found or already removed"

echo "✅ Core services removed"

# Remove message queue
echo "🗑️ Removing message queue..."
helm delete rabbitmq 2>/dev/null || echo "RabbitMQ not found or already removed"

echo "✅ Message queue removed"

# Remove databases
echo "🗑️ Removing databases..."
helm delete test-redis 2>/dev/null || echo "Redis not found or already removed"
helm delete test-postgresql 2>/dev/null || echo "PostgreSQL not found or already removed"
helm delete test-mariadb 2>/dev/null || echo "MariaDB not found or already removed"

echo "✅ Databases removed"

set -e  # Re-enable exit on error

# Remove ingress resources
echo "🗑️ Removing ingress resources..."
kubectl delete -f ./helm/ingress/ 2>/dev/null || echo "Ingress resources not found or already removed"

echo "✅ Ingress resources removed"

# Remove service accounts
echo "🗑️ Removing service accounts..."
kubectl delete serviceaccount pegasus-system-admin 2>/dev/null || echo "Service account not found or already removed"

echo "✅ Service accounts removed"

# Clean up persistent volumes (optional - uncomment if needed)
echo "🧹 Cleaning up persistent volumes..."
# kubectl delete pvc --all 2>/dev/null || echo "No PVCs to remove"
# kubectl delete pv --all 2>/dev/null || echo "No PVs to remove"

echo "✅ Cleanup completed"

# Remove storage directories (optional - uncomment if needed)
echo "🗑️ Removing storage directories..."
# sudo rm -rf /trusted-cloud 2>/dev/null || echo "Storage directories not found or already removed"

echo "✅ Storage cleanup completed"

echo "=========================================="
echo "Zillaforge Uninstallation completed!"
echo "All services have been removed from the cluster."
echo ""
echo "Note: The following were NOT removed:"
echo "- Persistent storage data (/trusted-cloud)"
echo "- Persistent Volume Claims (PVCs)"
echo "- Docker images"
echo "- K3s cluster"
echo ""
echo "To completely clean up:"
echo "1. Run 'sudo rm -rf /trusted-cloud' to remove storage"
echo "2. Run 'kubectl delete pvc --all' to remove PVCs"
echo "3. Run '/usr/local/bin/k3s-uninstall.sh' to remove K3s"
echo "=========================================="