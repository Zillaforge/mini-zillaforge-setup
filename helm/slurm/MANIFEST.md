# Helm SLURM Chart - 文件清单

本 Helm Chart 已成功创建，包含完整的 SLURM Kubernetes 部署定义。

## 目录结构

```
helm/slurm/
├── Chart.yaml                 # Helm Chart 元数据
├── values.yaml                # 默认配置值
├── README.md                  # 主文档
├── USAGE_EXAMPLES.md          # 使用示例和常见任务
├── CONVERSION_GUIDE.md        # YAML 到 Helm 的转换映射
└── templates/                 # Kubernetes 资源模板
    ├── namespace.yaml         # Kubernetes 命名空间
    ├── secret.yaml            # SLURM 凭证
    ├── pvc.yaml               # 持久卷声明
    ├── mysql.yaml             # MySQL/MariaDB StatefulSet
    ├── slurmdbd.yaml          # SLURM 数据库守护进程
    ├── slurmctld.yaml         # SLURM 控制器守护进程
    ├── slurmrestd.yaml        # SLURM REST API 守护进程
    └── compute-nodes.yaml     # 计算节点部署
```

## 文件说明

### Chart.yaml
- **描述**: Helm Chart 的元数据定义
- **内容**: 图表名称、版本、应用版本、关键字、维护者信息
- **修改频率**: 仅当发布新版本时

### values.yaml
- **描述**: 所有 Kubernetes 资源的默认配置参数
- **内容**: 
  - 全局设置（命名空间）
  - 存储配置（大小、存储类）
  - Secret 配置（数据库凭证）
  - 各个服务的配置（镜像、副本、资源、探针）
- **修改频率**: 按需要定制部署
- **行数**: 174 行

### README.md
- **描述**: Helm Chart 的主文档
- **内容**:
  - 组件概述
  - 安装说明（基本和自定义）
  - 配置说明
  - 升级和卸载指南
  - 服务访问说明
  - 前置条件

### USAGE_EXAMPLES.md
- **描述**: 实际使用示例和常见任务
- **内容**:
  - 快速开始指南
  - 自定义部署示例
  - 选择性启用组件
  - 升级策略
  - 常见任务（连接、检查状态、调试）
  - 故障排查步骤
  - 监控方法
  - 高级配置选项

### CONVERSION_GUIDE.md
- **描述**: 原始 YAML 文件到 Helm Chart 的转换说明
- **内容**:
  - 文件结构映射表
  - 配置变量映射表
  - 组件启用/禁用说明
  - 服务依赖关系说明
  - 生成最终 YAML 的方法

### 模板文件

#### namespace.yaml
- **功能**: 创建 SLURM 命名空间
- **特点**: 由 `namespace.create` 标志控制，可选创建
- **资源**: 1 个 Namespace

#### secret.yaml
- **功能**: 存储 MySQL 和 SLURM 凭证
- **特点**: 参数化密钥值，易于修改敏感信息
- **资源**: 1 个 Secret

#### pvc.yaml
- **功能**: 定义持久化存储
- **特点**: 三个独立的 PVC，大小可配
- **资源**: 
  - 1 个 PVC（工作目录，10Gi）
  - 1 个 PVC（MySQL，5Gi）
  - 1 个 PVC（JWT，1Gi）

#### mysql.yaml
- **功能**: 部署 MariaDB 数据库
- **特点**: 
  - StatefulSet 确保数据持久化
  - 完整的健康检查（存活探针和就绪探针）
  - 环境变量引用 Secret
  - 可配置的资源请求和限制
- **资源**: 1 个 Service，1 个 StatefulSet

#### slurmdbd.yaml
- **功能**: 部署 SLURM 数据库守护进程
- **特点**:
  - 等待 MySQL 就绪的 init 容器
  - JWT 密钥生成和挂载
  - 进程健康检查
  - 可参数化的副本数、资源和探针配置
- **资源**: 1 个 Service，1 个 Deployment

#### slurmctld.yaml
- **功能**: 部署 SLURM 控制器
- **特点**:
  - NodePort 服务暴露 SSH 和 SLURM 端口
  - 等待 slurmdbd 就绪
  - 特权容器以支持 SSH
  - scontrol ping 健康检查
  - 高资源配置（512Mi 内存）
- **资源**: 1 个 Service (NodePort)，1 个 Deployment

#### slurmrestd.yaml
- **功能**: 部署 SLURM REST API 服务
- **特点**:
  - NodePort 服务暴露 REST API 端口 (30820)
  - 等待 slurmctld 就绪
  - socket 文件存在性健康检查
  - 完整的资源和探针配置
- **资源**: 1 个 Service (NodePort)，1 个 Deployment

#### compute-nodes.yaml
- **功能**: 部署多个计算节点
- **特点**:
  - 使用 Helm range 循环生成多个节点
  - 每个节点独立的 Service 和 Deployment
  - 共享工作目录 PVC
  - slurmd 进程健康检查
  - 特权模式运行
  - 默认配置 c1 和 c2 两个节点
- **资源**: N 个 Service，N 个 Deployment（N = 计算节点数）

## 配置参数总览

### 全局参数
- `global.namespace`: 全局命名空间（默认: slurm）
- `namespace.create`: 是否创建命名空间（默认: true）
- `namespace.name`: 命名空间名称（默认: slurm）

### 存储参数
- `storage.storageClassName`: 存储类名（默认: standard）
- `storage.jobdir.size`: 工作目录大小（默认: 10Gi）
- `storage.mysql.size`: MySQL 存储大小（默认: 5Gi）
- `storage.jwt.size`: JWT 密钥存储大小（默认: 1Gi）

### Secret 参数
- `secrets.mysqlRootPassword`: MySQL root 密码
- `secrets.mysqlDatabase`: 数据库名称
- `secrets.mysqlUser`: 数据库用户
- `secrets.mysqlPassword`: 数据库用户密码

### 服务参数示例（MySQL）
- `mysql.enabled`: 是否启用（默认: true）
- `mysql.image.repository`: 镜像仓库（默认: mariadb）
- `mysql.image.tag`: 镜像标签（默认: 12）
- `mysql.image.pullPolicy`: 拉取策略（默认: IfNotPresent）
- `mysql.replicas`: 副本数（默认: 1）
- `mysql.service.type`: Service 类型（默认: ClusterIP）
- `mysql.service.port`: 端口（默认: 3306）
- `mysql.resources.requests.memory`: 内存请求（默认: 256Mi）
- `mysql.resources.requests.cpu`: CPU 请求（默认: 250m）
- `mysql.resources.limits.memory`: 内存限制（默认: 512Mi）
- `mysql.resources.limits.cpu`: CPU 限制（默认: 500m）

（其他服务参数结构类似）

## 快速命令参考

```bash
# 安装
helm install slurm ./helm/slurm

# 验证（生成 YAML 但不部署）
helm template slurm ./helm/slurm

# 升级
helm upgrade slurm ./helm/slurm

# 查看状态
helm status slurm

# 卸载
helm uninstall slurm

# 检查语法
helm lint ./helm/slurm

# 查看值
helm values ./helm/slurm
```

## 特点和改进

相比原始 YAML 文件：

1. ✅ **完全参数化** - 所有配置值都可外部控制
2. ✅ **模块化设计** - 每个组件独立在自己的模板中
3. ✅ **条件渲染** - 可选择启用/禁用组件
4. ✅ **版本管理** - Chart 版本独立管理
5. ✅ **易于升级** - 一个命令升级整个部署
6. ✅ **可重复使用** - 支持多个 SLURM 集群
7. ✅ **完整文档** - 包含使用指南和转换说明
8. ✅ **依赖管理** - 自动处理组件启动顺序
9. ✅ **标准化** - 遵循 Helm 最佳实践

## 验证转换

要验证从原始 YAML 到 Helm Chart 的转换是否正确：

```bash
# 1. 生成模板
helm template slurm ./helm/slurm > rendered.yaml

# 2. 比较与原始 YAML
# 生成的 YAML 应该包含原始 01-namespace.yaml 到 08-compute-nodes.yaml 中的所有资源

# 3. 检查差异
# 主要差异应该是参数变量的替换和条件块
```

## 下一步

1. **定制配置**: 根据需要修改 values.yaml
2. **选择镜像**: 确保 SLURM 镜像可用
3. **存储类**: 配置适当的 Kubernetes 存储类
4. **部署**: 使用 `helm install` 或 `helm upgrade` 部署
5. **验证**: 使用提供的故障排查步骤检查部署状态
