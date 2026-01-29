# SLURM Helm Chart

This Helm chart deploys a complete SLURM (Simple Linux Utility for Resource Management) cluster on Kubernetes.

## Components

The chart deploys the following components:

- **Namespace**: Dedicated namespace for SLURM resources
- **PersistentVolumeClaims**: Storage for job data, MySQL database, and JWT keys
- **Secret**: Credentials for MySQL and SLURM services
- **MySQL/MariaDB**: Database backend for SLURM accounting
- **slurmdbd**: SLURM database daemon
- **slurmctld**: SLURM control daemon
- **slurmrestd**: SLURM REST API daemon
- **Compute Nodes**: Worker nodes (c1, c2) for job execution

## Installation

### Basic Installation

```bash
helm install slurm ./helm/slurm
```

### Installation with Custom Values

```bash
helm install slurm ./helm/slurm -f custom-values.yaml
```

## Configuration

All configuration is managed through `values.yaml`. Key sections:

### Storage Configuration
```yaml
storage:
  storageClassName: standard  # Your storage class
  jobdir:
    size: 10Gi               # Job directory size
  mysql:
    size: 5Gi                # MySQL database size
  jwt:
    size: 1Gi                # JWT key storage size
```

### Secrets
```yaml
secrets:
  mysqlRootPassword: slurm_root_password
  mysqlDatabase: slurm_acct_db
  mysqlUser: slurm
  mysqlPassword: password
```

### Component Configuration

Each component (mysql, slurmdbd, slurmctld, slurmrestd, computeNodes) can be individually enabled/disabled and configured:

```yaml
mysql:
  enabled: true
  image:
    repository: mariadb
    tag: "12"
  resources:
    requests:
      memory: "256Mi"
      cpu: "250m"
```

### Compute Nodes

Configure the number of compute nodes and their properties:

```yaml
computeNodes:
  enabled: true
  nodes:
    - name: c1
      replicas: 1
    - name: c2
      replicas: 1
```

## Upgrade

```bash
helm upgrade slurm ./helm/slurm
```

## Uninstall

```bash
helm uninstall slurm
```

## Services and Access

- **MySQL**: `mysql.slurm:3306` (ClusterIP)
- **slurmdbd**: `slurmdbd.slurm:6819` (ClusterIP)
- **slurmctld**: `slurmctld.slurm:6817` (NodePort: 30017 for SSH on 22)
- **slurmrestd**: `slurmrestd.slurm:6820` (NodePort: 30820)
- **Compute Nodes**: `c1.compute-nodes.slurm:6818`, `c2.compute-nodes.slurm:6818`

## Prerequisites

- Kubernetes cluster with persistent volume support
- Helm 3.0+
- Default storage class configured or specify `storage.storageClassName`

## Notes

- All components use `slurm-docker-cluster:25.05.3` image
- Init containers handle startup dependencies (waiting for services to be ready)
- Health checks are configured for each component
- Resource requests and limits are pre-configured but can be adjusted in values.yaml
