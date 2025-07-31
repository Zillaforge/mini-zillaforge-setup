# Mini Zillaforge Setup

This repository contains the setup scripts and Helm charts for deploying a minimal Zillaforge environment with OpenStack integration.

## Directory Structure

```
mini-zillaforge-setup/
├── helm/                           # All Helm charts and configurations
│   ├── ingress/                    # Ingress configurations
│   ├── ldap/                       # LDAP service chart
│   ├── mariadb-galera/            # MariaDB Galera cluster chart
│   ├── pegasusiam/                # PegasusIAM service chart
│   ├── portal/                     # Admin and User portal charts
│   ├── postgresql/                 # PostgreSQL chart
│   ├── redis-sentinel/            # Redis Sentinel chart
│   ├── system-kong/               # Kong API Gateway chart
│   ├── vps/                       # Virtual Platform Service chart
│   ├── vrm/                       # Virtual Resource Manager chart
│   └── rabbit_values.yaml         # RabbitMQ configuration
├── prerequisite.sh                 # Install tools, build images, and prepare environment
├── install.sh                     # Install all Helm charts including VPS and VRM
├── post-configuration.sh          # Configure OpenStack integration
├── uninstall.sh                   # Remove all services and cleanup
└── README.md                      # This file
```

## Installation Process

The installation is streamlined into three main phases:

### 1. Prerequisites (`prerequisite.sh`)

**Run as root/sudo** - Installs required tools, builds images, and prepares the environment:
- System package updates (make, jq)
- Docker installation and configuration
- K3s Kubernetes cluster setup
- Helm installation
- **Docker image building** (utility images and service repositories)
- **Image cleanup** (removes base images and dangling images)
- **Image export** (saves Zillaforge images as tar files)
- **Image import** (imports tar files into K3s containerd)
- **OpenStack user setup** (if OpenStack is available)
- Required directory creation

```bash
sudo ./prerequisite.sh
```

**Note:** After running prerequisites, restart your terminal or run `source ~/.bashrc` to ensure environment variables are loaded.

### 2. Installation (`install.sh`)

Installs all Helm charts in the correct order:
- Databases (MariaDB, PostgreSQL, Redis)
- Message queue (RabbitMQ)
- Core services (PegasusIAM, LDAP, Kong API Gateway)
- **VPS and VRM services** (Virtual Platform Service and Virtual Resource Manager)
- User interfaces (Admin Portal, User Portal)
- Ingress configuration

```bash
./install.sh
```

### 3. Post-Configuration (`post-configuration.sh`)

Configures OpenStack integration and service interconnections:
- OpenStack environment setup
- External network configuration
- Cirros image deployment to OpenStack
- **IAM and VRM integration** (API calls and project configuration)
- Final service configuration

```bash
./post-configuration.sh
```

## Complete Setup

For a complete installation, run all three scripts in sequence:

```bash
# 1. Prerequisites (run as root)
sudo ./prerequisite.sh

# 2. Restart terminal or source bashrc
source ~/.bashrc

# 3. Install services
./install.sh

# 4. Configure integrations
./post-configuration.sh
```

## Uninstallation

Remove all installed services and resources:

```bash
./uninstall.sh
```

This will:
- Remove all Helm charts
- Clean up Kubernetes resources
- Remove service accounts
- Optionally clean up persistent volumes

## Prerequisites

Before running the installation, ensure you have:

1. **Ubuntu 22.04 LTS** (recommended)
2. **Root access** or sudo privileges for prerequisite.sh
3. **Internet connectivity** for downloading packages and cloning repositories
4. **OpenStack environment** (optional, for full integration):
   - `/home/ubuntu/venv/` with OpenStack CLI tools
   - `/etc/kolla/clouds.yaml` configuration
   - `../all-in-one` inventory file for kolla-ansible

**Note:** The setup process will automatically build all required Docker images, so no pre-built images are needed.

## What Gets Built and Installed

### Docker Images Built:
- **Utility Images**: debugger, golang
- **Service Images**: 
  - ldapservice
  - pegasusiam  
  - virtualregistrymanagement
  - virtualplatformservice
  - cloudstorage
  - kongauthplugin
  - eventpublishplugin
  - kongresponsetransformerplugin
  - adminpanel
  - userportal

### Services Installed:
- **Databases**: MariaDB Galera, PostgreSQL, Redis Sentinel
- **Message Queue**: RabbitMQ
- **Core Services**: PegasusIAM, LDAP, Kong API Gateway
- **Platform Services**: VPS (Virtual Platform Service), VRM (Virtual Resource Manager)  
- **User Interfaces**: Admin Portal, User Portal
- **Networking**: Ingress controllers and routing

## Access URLs

After successful installation, access the services at:

- **Admin Portal**: `http://admin.<your-ip>.nip.io`
- **User Portal**: `http://user.<your-ip>.nip.io`  
- **Kong API Gateway**: `http://kong.<your-ip>.nip.io`

Replace `<your-ip>` with your actual public IP address (automatically detected during installation).

## Troubleshooting

### Common Issues

1. **Permission denied**: Ensure prerequisite.sh is run with sudo
2. **Build failures**: Check internet connectivity and GitHub repository access
3. **K3s not ready**: Wait a few minutes after prerequisite installation for K3s to initialize
4. **Helm chart failures**: Check if all images are available: `kubectl get pods -A`
5. **OpenStack integration**: Ensure OpenStack environment is properly configured

### Debugging Commands

```bash
# Check pod status
kubectl get pods -A

# View pod logs  
kubectl logs <pod-name> -n <namespace>

# Check Helm releases
helm list -A

# View recent events
kubectl get events --sort-by=.metadata.creationTimestamp

# Check Docker images
docker images | grep Zillaforge

# Check imported images in K3s
sudo ctr --address /run/k3s/containerd/containerd.sock -n k8s.io images ls
```

### Clean Installation

For a completely fresh installation:

1. **Uninstall services**: `./uninstall.sh`
2. **Remove persistent data**: `sudo rm -rf /trusted-cloud`
3. **Remove Docker images**: `docker system prune -a`
4. **Uninstall K3s**: `/usr/local/bin/k3s-uninstall.sh`
5. **Clean start**: Run the installation process again

## Advanced Configuration

### OpenStack Integration
The setup automatically detects and integrates with OpenStack if available. If you don't have OpenStack, the system will work with reduced functionality.

### Custom Configuration
Configuration files are located in the `helm/` directory. You can customize values before installation:
- Database configurations in `helm/mariadb-galera/`, `helm/postgresql/`, `helm/redis-sentinel/`
- Service configurations in respective service directories
- Ingress rules in `helm/ingress/`

### Resource Requirements
Minimum recommended resources:
- **CPU**: 8 cores
- **RAM**: 16GB  
- **Storage**: 100GB available space
- **Network**: Stable internet connection for image building

## Migration from Legacy Setup

If migrating from the old setup process:

1. **Remove old files**: The following files are no longer used:
   - `build_images.sh` (integrated into `prerequisite.sh`)
   - `addopuser.sh` (integrated into `prerequisite.sh`)
   - `config.sh` and `config2.sh` (functionality distributed across scripts)

2. **Updated process**: Use the new 3-step process instead of the old multi-script approach

3. **Simplified workflow**: Everything is now contained in three main scripts with clear separation of concerns