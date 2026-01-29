# YAML 到 Helm Chart 转换映射

本文档说明原始 Kubernetes YAML 文件如何转换为 Helm Chart 模板。

## 文件结构映射

| 原始 YAML 文件 | Helm 模板文件 | 说明 |
|---|---|---|
| `01-namespace.yaml` | `namespace.yaml` | Kubernetes 命名空间，由 `namespace.create` 控制 |
| `02-pvc.yaml` | `pvc.yaml` | 三个 PVC 资源：jobdir、mysql-storage、jwt |
| `03-secret.yaml` | `secret.yaml` | SLURM 凭证密钥 |
| `04-mysql.yaml` | `mysql.yaml` | MySQL StatefulSet 和 Service |
| `05-slurmdbd.yaml` | `slurmdbd.yaml` | slurmdbd Deployment 和 Service |
| `06-slurmctld.yaml` | `slurmctld.yaml` | slurmctld Deployment 和 Service (NodePort) |
| `07-slurmrestd.yaml` | `slurmrestd.yaml` | slurmrestd Deployment 和 Service (NodePort) |
| `08-compute-nodes.yaml` | `compute-nodes.yaml` | 计算节点 Deployments (c1, c2) 和 Services |

## 关键配置变量映射

### 存储配置

| 原始 YAML 配置 | Helm values 配置 | 默认值 |
|---|---|---|
| PVC `storage: 10Gi` | `storage.jobdir.size` | `10Gi` |
| PVC `storage: 5Gi` | `storage.mysql.size` | `5Gi` |
| PVC `storage: 1Gi` | `storage.jwt.size` | `1Gi` |
| `storageClassName: standard` | `storage.storageClassName` | `standard` |

### Secret 配置

| 原始 YAML 配置 | Helm values 配置 | 默认值 |
|---|---|---|
| `MYSQL_ROOT_PASSWORD` | `secrets.mysqlRootPassword` | `slurm_root_password` |
| `MYSQL_DATABASE` | `secrets.mysqlDatabase` | `slurm_acct_db` |
| `MYSQL_USER` | `secrets.mysqlUser` | `slurm` |
| `MYSQL_PASSWORD` | `secrets.mysqlPassword` | `password` |

### MySQL 配置

| 原始 YAML 配置 | Helm values 配置 | 默认值 |
|---|---|---|
| `image: mariadb:12` | `mysql.image.repository`, `mysql.image.tag` | `mariadb`, `12` |
| `replicas: 1` | `mysql.replicas` | `1` |
| `port: 3306` | `mysql.service.port` | `3306` |
| `memory: 256Mi` | `mysql.resources.requests.memory` | `256Mi` |
| `cpu: 250m` | `mysql.resources.requests.cpu` | `250m` |
| `initialDelaySeconds: 30` | `mysql.livenessProbe.initialDelaySeconds` | `30` |

### slurmdbd 配置

| 原始 YAML 配置 | Helm values 配置 | 默认值 |
|---|---|---|
| `image: slurm-docker-cluster:25.05.3` | `slurmdbd.image.repository`, `slurmdbd.image.tag` | `slurm-docker-cluster`, `25.05.3` |
| `replicas: 1` | `slurmdbd.replicas` | `1` |
| `port: 6819` | `slurmdbd.service.port` | `6819` |
| `memory: 256Mi` | `slurmdbd.resources.requests.memory` | `256Mi` |
| `initialDelaySeconds: 20` | `slurmdbd.livenessProbe.initialDelaySeconds` | `20` |

### slurmctld 配置

| 原始 YAML 配置 | Helm values 配置 | 默认值 |
|---|---|---|
| `image: slurm-docker-cluster:25.05.3` | `slurmctld.image.repository`, `slurmctld.image.tag` | `slurm-docker-cluster`, `25.05.3` |
| `port: 6817` | `slurmctld.service.slurmPort` | `6817` |
| `nodePort: 30022` (SSH) | `slurmctld.service.sshNodePort` | `30022` |
| `memory: 512Mi` | `slurmctld.resources.requests.memory` | `512Mi` |
| `memory limit: 1Gi` | `slurmctld.resources.limits.memory` | `1Gi` |

### slurmrestd 配置

| 原始 YAML 配置 | Helm values 配置 | 默认值 |
|---|---|---|
| `image: slurm-docker-cluster:25.05.3` | `slurmrestd.image.repository`, `slurmrestd.image.tag` | `slurm-docker-cluster`, `25.05.3` |
| `port: 6820` | `slurmrestd.service.port` | `6820` |
| `nodePort: 30820` | `slurmrestd.service.nodePort` | `30820` |
| `memory: 256Mi` | `slurmrestd.resources.requests.memory` | `256Mi` |

### 计算节点配置

| 原始 YAML 配置 | Helm values 配置 | 默认值 |
|---|---|---|
| 节点名 `c1`, `c2` | `computeNodes.nodes[*].name` | `c1`, `c2` |
| `replicas: 1` | `computeNodes.nodes[*].replicas` | `1` |
| `image: slurm-docker-cluster:25.05.3` | `computeNodes.image.*` | `slurm-docker-cluster:25.05.3` |
| `memory: 256Mi` | `computeNodes.resources.requests.memory` | `256Mi` |

## 模板变量使用示例

### namespace.yaml
```yaml
{{- if .Values.namespace.create }}  # 条件创建命名空间
{{ .Values.namespace.name }}         # 使用命名空间名称
```

### pvc.yaml
```yaml
{{ .Values.storage.jobdir.size }}    # 工作目录大小
{{ .Values.storage.storageClassName }}  # 存储类
```

### mysql.yaml
```yaml
{{ .Values.mysql.image.repository }}:{{ .Values.mysql.image.tag }}  # 镜像
{{ .Values.mysql.replicas }}                                        # 副本数
{{ .Values.mysql.service.port }}                                    # 端口
{{ .Values.mysql.resources.requests.memory | quote }}               # 内存请求
```

### compute-nodes.yaml
```yaml
{{- range .Values.computeNodes.nodes }}  # 循环计算节点列表
{{ .name }}                              # 节点名称
{{ .replicas }}                          # 副本数
{{ $.Values.computeNodes.image.tag }}    # 镜像标签（使用 $ 访问全局值）
```

## 启用/禁用组件

每个主要组件都可以独立启用或禁用：

```yaml
{{- if .Values.mysql.enabled }}        # 在模板中检查启用状态
# MySQL 资源定义
{{- end }}
```

组件标志：
- `mysql.enabled` - MySQL/MariaDB 数据库
- `slurmdbd.enabled` - SLURM 数据库守护进程
- `slurmctld.enabled` - SLURM 控制器守护进程
- `slurmrestd.enabled` - SLURM REST API 守护进程
- `computeNodes.enabled` - 计算节点

## 服务发现和依赖关系

Helm Chart 保留了原始 YAML 中的所有依赖关系：

1. **slurmdbd** 等待 MySQL 就绪（init 容器：wait-for-mysql）
2. **slurmctld** 等待 slurmdbd 就绪（init 容器：wait-for-slurmdbd）
3. **slurmrestd** 等待 slurmctld 就绪（init 容器：wait-for-slurmctld）
4. **计算节点** 等待 slurmctld 就绪（init 容器：wait-for-slurmctld）

所有启动探针和就绪探针都已包含并参数化。

## 重要变更

相比原始 YAML，Helm Chart 提供的改进：

1. **参数化配置** - 所有硬编码值都可通过 values.yaml 修改
2. **条件渲染** - 可以启用或禁用特定组件
3. **可重复使用** - 支持多个 SLURM 集群部署（不同名称）
4. **版本管理** - Helm Chart 版本和应用版本分离
5. **易于升级** - 使用 `helm upgrade` 进行更新
6. **一致性** - 所有资源遵循相同的命名约定

## 生成最终 YAML

验证转换是否正确：

```bash
# 生成完整的 Kubernetes 资源
helm template slurm ./helm/slurm > rendered.yaml

# 生成特定组件
helm template slurm ./helm/slurm -s templates/mysql.yaml > mysql-only.yaml

# 使用自定义值生成
helm template slurm ./helm/slurm -f custom-values.yaml > custom-rendered.yaml
```

生成的 YAML 应该与原始 YAML 文件结构相同，但使用来自 values.yaml 的配置值。
