# Mini Zillaforge Setup

This repository contains the setup scripts and Helm charts for deploying a minimal Zillaforge environment with OpenStack integration.

## Directory Structure

```
mini-zillaforge-setup/
├── helm/                           # All Helm charts and configurations
│   ├── cloud-storage/              # Cloud Storage service chart
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

## Complete Setup

For a complete installation, run all three scripts in sequence:

```bash
# Clone the repository, and initialize submodules
git clone https://github.com/Zillaforge/mini-zillaforge-setup.git
cd mini-zillaforge-setup
git submodule update --init --recursive


# 1. Prerequisites
./prerequisite.sh
source ~/.bashrc


# 2. Install services
./install.sh

# 3. Configure integrations
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


## Installation Process

The installation is streamlined into three main phases:

### 1. Prerequisites (`prerequisite.sh`)

- **System Preparation:**
  - Updates system packages using `apt update`.
  - Installs essential tools like `make` and `jq`.

- **Containerization & Orchestration Setup:**
  - **Docker:** Installs the latest version of Docker Engine and adds the current user to the `docker` group.
  - **K3s:** Installs a lightweight Kubernetes distribution (K3s) and configures `kubectl` access by setting the `KUBECONFIG` environment variable in `~/.bashrc`.
  - **Helm:** Installs the Helm package manager for Kubernetes.

- **Image Build and Management:**
  - **Builds Utility Images:** Clones the `utility-image-builder` repository to build necessary utility images:
    - `debugger` image is used for debugging purposes.
    - `golang` image is used for building Go applications.
  - **Builds Service Images:** Clones and builds all required Zillaforge service images, including:
    - `ldapservice`
    - `pegasusiam`
    - `virtualregistrymanagement`
    - `virtualplatformservice`
    - `cloudstorage`
    - `kongauthplugin`
    - `eventpublishplugin`
    - `kongresponsetransformerplugin`
    - `adminpanel`
    - `userportal`
  - **Image Import to K3s:**
    - Exports all newly built `Zillaforge/*` images to `.tar` archives.
    - Imports these archives directly into the K3s containerd image registry, making them available to the cluster without needing a separate Docker registry.

- **Directory Setup:**
  - Creates the `/trusted-cloud` directory structure required for persistent volume storage for services like PostgreSQL, Redis, and other stateful applications.

**Note:** After running prerequisites, restart your terminal or run `source ~/.bashrc` to ensure environment variables like `KUBECONFIG` are loaded correctly.

### 2. Installation (`install.sh`)

This script automates the deployment of all Zillaforge services onto the prepared Kubernetes cluster using Helm. It follows a specific, ordered installation process to ensure dependencies are met.


- **Dynamic Configuration:**
  - Automatically detects the machine's public IP address and hostname.
  - Uses `sed` to dynamically update Helm values files (`values-*.yaml`) and ingress configurations, ensuring all services and access points are correctly configured for the current environment.

- **Core Service Installation:**
    The script installs services in the following logical order:
  - **Databases:** Deploys `MariaDB Galera`, `PostgreSQL`, `RabbitMQ`, and `Redis Sentinel` to provide the foundational data stores.
  - **Core Services:** Deploys `PegasusIAM`, `LDAP`, and the `System Kong` API Gateway.
  - **Web Portals:** Installs the `Admin Portal` and `User Portal`.
  - **Ingress Rules:** Applies Kubernetes Ingress rules to expose the services to the outside world.

- **OpenStack Integration:**
    - **User Setup:** Assigns the necessary roles (`admin`) to the default LDAP user within the OpenStack project.

- **Platform Services Installation:**
    - Deploys the `Virtual Resource Manager (VRM)` and `Virtual Platform Service (VPS)`.
    - Deploys the `Cloud Storage (CS)` service, creating two instances: one for public access and one for internal site storage.


### 3. Post-Configuration (`post-configuration.sh`)

This final script completes the setup by deeply integrating the deployed services with the OpenStack backend and performing necessary final adjustments.


- **OpenStack Environment Finalization:**
    - **VNC Console Access:** Updates the Kolla Ansible configuration (`globals.yml`) to enable VNC consoles access.
    - **Networking:** Creates a default external network (`ExNet`) and subnet in OpenStack, which is required for virtual machines to get public connectivity.
    - **Test Image Setup:** Downloads a standard Cirros cloud image, uploads it to OpenStack's image service (Glance), and tags it for use.

- **Kong API Gateway Reload:**
    - Imports the latest service routes and configurations from a local `kong.yaml` file into the Kong database.
    - Restarts the Kong deployment to ensure all new configurations are loaded and active.

- **User Portal Configuration:**
    - Removes the `Content-Security-Policy` header from the User Portal's Nginx configuration. This is often done to prevent issues with embedding or cross-origin content in specific deployment scenarios.

- **IAM and VRM Service Integration:**
    This is the most critical part of the script, where the abstract Zillaforge services are linked to the concrete OpenStack resources.
    - **Fetches an Admin Token:** Authenticates with the PegasusIAM API to get an administrative token for performing privileged actions.
    - **Links Projects:** Associates the default Zillaforge project with the `trustedcloud` project in OpenStack by updating its metadata with the OpenStack project's UUID.
    - **Imports Image to VRM:** Makes an API call to the Virtual Resource Manager (VRM) to import the Cirros image from OpenStack. This makes the image visible and usable within the Zillaforge platform, linking the VRM's catalog to OpenStack's image repository.

After these steps, the script prints the final access URLs and default credentials, and the system is ready for use.






