# SLURM Helm Chart - 部署和使用示例

## 快速开始

### 1. 基本部署

```bash
# 在默认命名空间部署
helm install slurm ./helm/slurm

# 检查部署状态
helm status slurm

# 查看生成的资源
kubectl get all -n slurm

# 查看日志
kubectl logs -n slurm -l app=slurmctld
kubectl logs -n slurm -l app=slurmdbd
kubectl logs -n slurm -l app=mysql
```

### 2. 自定义部署

创建 `custom-values.yaml`:

```yaml
storage:
  storageClassName: my-storage-class  # 修改存储类
  jobdir:
    size: 20Gi                         # 增加工作目录大小
  mysql:
    size: 10Gi

secrets:
  mysqlPassword: my-secure-password    # 修改密码

computeNodes:
  nodes:
    - name: c1
      replicas: 1
    - name: c2
      replicas: 1
    - name: c3
      replicas: 1                      # 添加更多计算节点
```

部署:

```bash
helm install slurm ./helm/slurm -f custom-values.yaml
```

### 3. 只启用特定组件

```bash
helm install slurm ./helm/slurm \
  --set mysql.enabled=true \
  --set slurmdbd.enabled=true \
  --set slurmctld.enabled=true \
  --set slurmrestd.enabled=false \
  --set computeNodes.enabled=false
```

### 4. 升级部署

```bash
# 修改 values.yaml 后升级
helm upgrade slurm ./helm/slurm

# 升级并应用自定义值
helm upgrade slurm ./helm/slurm -f custom-values.yaml
```

### 5. 查看即将部署的资源（不实际部署）

```bash
helm template slurm ./helm/slurm > rendered.yaml
cat rendered.yaml
```

### 6. 卸载

```bash
helm uninstall slurm
```

## 常见任务

### 连接到 SLURM 控制器

```bash
# SSH 到 slurmctld (使用 NodePort 30022)
ssh -p 30022 node_ip

# 或通过 kubectl 进入容器
kubectl exec -it -n slurm deployment/slurmctld -- /bin/bash
```

### 检查 SLURM 状态

```bash
# 进入 slurmctld 容器
kubectl exec -it -n slurm deployment/slurmctld -- /bin/bash

# 在容器内运行 SLURM 命令
sinfo                    # 查看节点信息
scontrol show node       # 查看节点详细状态
squeue                   # 查看任务队列
sacct                    # 查看账户信息
```

### 查看 REST API

```bash
# 获取 slurmrestd 的 NodePort
kubectl get svc -n slurm slurmrestd

# 访问 REST API
curl -X GET http://node_ip:30820/slurm/v0.0.39/nodes
```

### 修改资源配置

```bash
# 只修改 MySQL 资源
helm upgrade slurm ./helm/slurm \
  --set mysql.resources.requests.memory=512Mi \
  --set mysql.resources.limits.memory=1Gi

# 修改计算节点副本数
helm upgrade slurm ./helm/slurm \
  --set computeNodes.nodes[0].replicas=3 \
  --set computeNodes.nodes[1].replicas=2
```

### 查看 Secret

```bash
# 获取 MySQL 密码
kubectl get secret -n slurm slurm-credentials -o jsonpath='{.data.MYSQL_PASSWORD}' | base64 -d

# 查看所有 secret
kubectl describe secret -n slurm slurm-credentials
```

### 查看 PVC 和存储

```bash
# 列出所有 PVC
kubectl get pvc -n slurm

# 查看存储使用情况
kubectl get pvc -n slurm -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.capacity.storage}{"\n"}{end}'
```

## 故障排查

### 检查 Pod 状态

```bash
# 查看所有 pod
kubectl get pods -n slurm

# 查看特定 pod 的详细信息
kubectl describe pod -n slurm <pod-name>

# 查看 pod 日志
kubectl logs -n slurm <pod-name>
kubectl logs -n slurm <pod-name> --previous  # 查看之前崩溃的日志
```

### 检查 init 容器

```bash
# 查看 init 容器日志
kubectl logs -n slurm deployment/slurmdbd -c wait-for-mysql
```

### 检查事件

```bash
# 查看命名空间中的事件
kubectl get events -n slurm --sort-by='.lastTimestamp'
```

### 验证连接

```bash
# 测试 MySQL 连接
kubectl exec -it -n slurm deployment/mysql -- mysql -u slurm -p

# 测试 slurmdbd 端口
kubectl exec -it -n slurm deployment/slurmdbd -- nc -zv slurmdbd 6819

# 测试 slurmctld 端口
kubectl exec -it -n slurm deployment/slurmctld -- nc -zv slurmctld 6817
```

## 监控

### 监控资源使用

```bash
# 查看 Pod 资源使用
kubectl top pods -n slurm

# 查看节点资源使用
kubectl top nodes
```

### 监视日志

```bash
# 实时查看 slurmctld 日志
kubectl logs -f -n slurm deployment/slurmctld

# 跟踪所有组件的日志
kubectl logs -f -n slurm -l app=slurmctld --all-containers=true
```

## 高级配置

### 使用外部 MySQL

修改 values.yaml:

```yaml
mysql:
  enabled: false  # 禁用内部 MySQL

# 添加环境变量指向外部 MySQL
# 这需要修改 slurmdbd 模板来添加连接字符串
```

### 自定义镜像

```bash
helm upgrade slurm ./helm/slurm \
  --set mysql.image.repository=my-registry/mysql \
  --set mysql.image.tag=custom-tag \
  --set slurmctld.image.repository=my-registry/slurm-docker-cluster \
  --set slurmctld.image.tag=custom-tag
```

### 配置 NodePort

```bash
helm upgrade slurm ./helm/slurm \
  --set slurmctld.service.sshNodePort=32022 \
  --set slurmrestd.service.nodePort=32820
```
