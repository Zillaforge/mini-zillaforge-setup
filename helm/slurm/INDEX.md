# Helm SLURM Chart - 快速导航

欢迎使用 SLURM Kubernetes Helm Chart！本文档帮助您快速找到所需的信息。

## 📚 文档导航

### 🚀 入门指南
**新用户应该从这里开始：**

1. **[README.md](README.md)** - Helm Chart 主文档
   - Chart 包含的组件
   - 如何安装和卸载
   - 基本配置说明
   - 服务访问方式

### 💡 实践指南

2. **[USAGE_EXAMPLES.md](USAGE_EXAMPLES.md)** - 实际使用示例和常见任务
   - 快速开始（5 分钟部署）
   - 自定义部署示例
   - 常见任务（连接、检查状态、调试）
   - 故障排查步骤
   - 监控方法

### 🔄 技术参考

3. **[CONVERSION_GUIDE.md](CONVERSION_GUIDE.md)** - YAML 到 Helm 的转换映射
   - 原始文件到模板的对应关系
   - 配置参数映射表
   - 模板变量使用示例
   - 组件依赖关系说明

4. **[MANIFEST.md](MANIFEST.md)** - 文件详细清单
   - 完整的目录结构
   - 每个文件的详细说明
   - 所有配置参数总览
   - 快速命令参考

### 📋 项目总结

5. **[SUMMARY.md](SUMMARY.md)** - 转换完成总结
   - 项目概述
   - 转换统计
   - 质量指标
   - 后续改进建议

## 📁 文件结构

```
helm/slurm/
├── 📄 Chart.yaml                     # Chart 元数据
├── 📄 values.yaml                    # 配置参数（174 行）
│
├── 📖 文档文件
├── 📄 README.md                      # ⭐ 从这里开始
├── 📄 USAGE_EXAMPLES.md              # 实践示例
├── 📄 CONVERSION_GUIDE.md            # 技术细节
├── 📄 MANIFEST.md                    # 文件说明
├── 📄 SUMMARY.md                     # 项目总结
├── 📄 INDEX.md                       # 本文件
│
└── 📁 templates/                     # Kubernetes 模板（8 个文件）
    ├── namespace.yaml                # 命名空间
    ├── secret.yaml                   # 凭证
    ├── pvc.yaml                      # 存储
    ├── mysql.yaml                    # 数据库
    ├── slurmdbd.yaml                 # DB 守护进程
    ├── slurmctld.yaml                # 控制器
    ├── slurmrestd.yaml               # REST API
    └── compute-nodes.yaml            # 计算节点
```

## 🎯 快速参考

### 我想要...

#### 📥 部署 SLURM
```bash
helm install slurm ./helm/slurm
```
👉 详见 [README.md - 安装](README.md#installation)

#### ⚙️ 自定义配置
1. 编辑 `values.yaml`
2. 或使用命令行参数：
```bash
helm install slurm ./helm/slurm --set mysql.replicas=3
```
👉 详见 [USAGE_EXAMPLES.md - 自定义部署](USAGE_EXAMPLES.md#2-自定义部署)

#### 🔍 了解有哪些配置选项
👉 参考 [values.yaml](values.yaml) 或 [MANIFEST.md - 配置参数总览](MANIFEST.md#配置参数总览)

#### 🐛 排查问题
1. 检查 Pod 状态
2. 查看日志
3. 验证连接
👉 详见 [USAGE_EXAMPLES.md - 故障排查](USAGE_EXAMPLES.md#故障排查)

#### 📊 监控和检查状态
```bash
kubectl get pods -n slurm
kubectl logs -n slurm deployment/slurmctld
```
👉 详见 [USAGE_EXAMPLES.md - 监控](USAGE_EXAMPLES.md#监控)

#### 🔄 升级已有部署
```bash
helm upgrade slurm ./helm/slurm
```
👉 详见 [README.md - 升级](README.md#upgrade)

#### 🗑️ 卸载
```bash
helm uninstall slurm
```
👉 详见 [README.md - 卸载](README.md#uninstall)

#### 📚 了解转换过程
👉 参考 [CONVERSION_GUIDE.md](CONVERSION_GUIDE.md)

#### 🎓 学习 Helm 模板语法
👉 参考 [CONVERSION_GUIDE.md - 模板变量使用示例](CONVERSION_GUIDE.md#模板变量使用示例)

## 🔑 关键概念

### 命名空间
- **默认**: `slurm`
- **可配置**: 通过 `namespace.name` 修改
- **自动创建**: 通过 `namespace.create: true` 控制

### 存储
- **工作目录**: 10Gi (可调)
- **MySQL 数据库**: 5Gi (可调)
- **JWT 密钥**: 1Gi (可调)
- **存储类**: `standard` (可调)

### 组件
| 组件 | 端口 | 类型 | 可选 |
|---|---|---|---|
| MySQL | 3306 | ClusterIP | ❌ |
| slurmdbd | 6819 | ClusterIP | ❌ |
| slurmctld | 6817/22 | NodePort | ✅ |
| slurmrestd | 6820 | NodePort | ✅ |
| 计算节点 | 6818 | ClusterIP | ✅ |

### 可配置项
- **镜像**: 存储库和标签
- **副本**: 每个服务的实例数
- **资源**: CPU 和内存请求/限制
- **探针**: 启动延迟、检查间隔等
- **存储**: 大小和存储类
- **凭证**: 数据库密码

## ⚡ 常用命令

```bash
# 验证 Chart
helm lint ./helm/slurm

# 查看生成的 YAML
helm template slurm ./helm/slurm

# 模拟部署（不实际创建）
helm install slurm ./helm/slurm --dry-run --debug

# 部署
helm install slurm ./helm/slurm

# 查看部署状态
helm status slurm

# 更新部署
helm upgrade slurm ./helm/slurm

# 回滚部署
helm rollback slurm

# 卸载
helm uninstall slurm

# 列出所有 release
helm list
```

## 🆘 需要帮助？

| 问题 | 位置 |
|---|---|
| 如何安装？ | [README.md](README.md) |
| 如何配置？ | [README.md - 配置](README.md#configuration) 或 [USAGE_EXAMPLES.md](USAGE_EXAMPLES.md) |
| 支持什么参数？ | [values.yaml](values.yaml) 或 [MANIFEST.md - 配置参数总览](MANIFEST.md#配置参数总览) |
| 如何调试？ | [USAGE_EXAMPLES.md - 故障排查](USAGE_EXAMPLES.md#故障排查) |
| 原始 YAML 在哪里？ | [CONVERSION_GUIDE.md - 文件结构映射](CONVERSION_GUIDE.md#文件结构映射) |
| 为什么要用 Helm？ | [SUMMARY.md - 使用场景](SUMMARY.md#使用场景) |

## 🚀 极速开始（3 步）

### 第 1 步：验证前置条件
```bash
kubectl cluster-info      # Kubernetes 集群就绪
helm version              # Helm 3.0+
```

### 第 2 步：查看生成的资源
```bash
helm template slurm ./helm/slurm | head -20
```

### 第 3 步：部署
```bash
helm install slurm ./helm/slurm
helm status slurm
kubectl get pods -n slurm
```

就这样！🎉

## 📞 下一步

1. **了解更多**: 阅读 [README.md](README.md)
2. **尝试示例**: 查看 [USAGE_EXAMPLES.md](USAGE_EXAMPLES.md)
3. **深入学习**: 参考 [CONVERSION_GUIDE.md](CONVERSION_GUIDE.md)
4. **自定义配置**: 编辑 [values.yaml](values.yaml)
5. **部署**: 使用 `helm install`

---

**版本**: 1.0.0  
**应用**: SLURM 25.05.3  
**创建日期**: 2026年1月22日

**建议**: 📌 将本导航页面加入书签，便于快速访问！
