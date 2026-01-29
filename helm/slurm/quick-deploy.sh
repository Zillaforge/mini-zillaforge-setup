#!/bin/bash
# SLURM Helm Chart 快速部署脚本
# 用途: 快速安装或升级 SLURM Helm Chart
# 使用: ./quick-deploy.sh [install|upgrade|uninstall|verify|template]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_NAME="slurm"
CHART_PATH="$SCRIPT_DIR"
RELEASE_NAME="${SLURM_RELEASE_NAME:-slurm}"
NAMESPACE="${SLURM_NAMESPACE:-slurm}"

# 颜色定义（用于输出）
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 函数: 打印带颜色的消息
print_msg() {
    local color=$1
    local msg=$2
    echo -e "${color}${msg}${NC}"
}

# 函数: 打印标题
print_title() {
    echo ""
    print_msg "$BLUE" "========================================"
    print_msg "$BLUE" "$1"
    print_msg "$BLUE" "========================================"
}

# 函数: 检查前置条件
check_prerequisites() {
    print_title "检查前置条件"
    
    # 检查 helm
    if ! command -v helm &> /dev/null; then
        print_msg "$RED" "❌ 错误: 未找到 helm 命令"
        print_msg "$YELLOW" "请先安装 Helm: https://helm.sh/docs/intro/install/"
        exit 1
    fi
    print_msg "$GREEN" "✅ Helm 已安装: $(helm version --short)"
    
    # 检查 kubectl
    if ! command -v kubectl &> /dev/null; then
        print_msg "$RED" "❌ 错误: 未找到 kubectl 命令"
        print_msg "$YELLOW" "请先安装 kubectl: https://kubernetes.io/docs/tasks/tools/"
        exit 1
    fi
    print_msg "$GREEN" "✅ Kubectl 已安装: $(kubectl version --client --short)"
    
    # 检查 Kubernetes 集群
    if ! kubectl cluster-info &> /dev/null; then
        print_msg "$RED" "❌ 错误: 无法连接到 Kubernetes 集群"
        print_msg "$YELLOW" "请确保 kubeconfig 配置正确"
        exit 1
    fi
    print_msg "$GREEN" "✅ Kubernetes 集群就绪"
    
    # 检查 Chart 路径
    if [ ! -f "$CHART_PATH/Chart.yaml" ]; then
        print_msg "$RED" "❌ 错误: Chart.yaml 未找到"
        print_msg "$YELLOW" "请在 Chart 目录中运行此脚本"
        exit 1
    fi
    print_msg "$GREEN" "✅ Chart 文件就绪"
}

# 函数: 验证 Chart
verify_chart() {
    print_title "验证 Helm Chart"
    helm lint "$CHART_PATH"
    print_msg "$GREEN" "✅ Chart 验证通过"
}

# 函数: 生成模板
show_template() {
    print_title "生成 Kubernetes 资源模板"
    
    local output_file="${RELEASE_NAME}-rendered.yaml"
    helm template "$RELEASE_NAME" "$CHART_PATH" > "$output_file"
    
    print_msg "$GREEN" "✅ 模板已生成: $output_file"
    
    # 显示资源摘要
    echo ""
    print_msg "$BLUE" "资源摘要:"
    grep "^kind:" "$output_file" | sort | uniq -c
    
    echo ""
    print_msg "$YELLOW" "提示: 完整的 YAML 已保存到 $output_file"
}

# 函数: 模拟部署
dry_run() {
    print_title "模拟部署（dry-run）"
    
    helm install "$RELEASE_NAME" "$CHART_PATH" \
        --namespace "$NAMESPACE" \
        --create-namespace \
        --dry-run \
        --debug
    
    print_msg "$GREEN" "✅ 模拟部署检查通过"
}

# 函数: 安装
install() {
    print_title "安装 SLURM Helm Chart"
    
    # 检查 release 是否已存在
    if helm list -n "$NAMESPACE" | grep -q "^$RELEASE_NAME"; then
        print_msg "$YELLOW" "⚠️  Release '$RELEASE_NAME' 已存在"
        read -p "是否要升级而不是安装? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            upgrade
            return
        else
            print_msg "$RED" "❌ 已取消"
            exit 1
        fi
    fi
    
    # 执行安装
    helm install "$RELEASE_NAME" "$CHART_PATH" \
        --namespace "$NAMESPACE" \
        --create-namespace
    
    print_msg "$GREEN" "✅ SLURM Chart 已安装"
    
    # 显示后续步骤
    echo ""
    print_msg "$BLUE" "后续步骤:"
    echo "  1. 查看部署状态: kubectl get pods -n $NAMESPACE"
    echo "  2. 查看 release 信息: helm status $RELEASE_NAME -n $NAMESPACE"
    echo "  3. 查看日志: kubectl logs -n $NAMESPACE deployment/slurmctld"
}

# 函数: 升级
upgrade() {
    print_title "升级 SLURM Helm Chart"
    
    # 检查 release 是否存在
    if ! helm list -n "$NAMESPACE" | grep -q "^$RELEASE_NAME"; then
        print_msg "$RED" "❌ Release '$RELEASE_NAME' 不存在"
        print_msg "$YELLOW" "请先运行: $0 install"
        exit 1
    fi
    
    # 执行升级
    helm upgrade "$RELEASE_NAME" "$CHART_PATH" \
        --namespace "$NAMESPACE"
    
    print_msg "$GREEN" "✅ SLURM Chart 已升级"
}

# 函数: 卸载
uninstall() {
    print_title "卸载 SLURM Helm Chart"
    
    # 确认卸载
    read -p "确实要卸载 release '$RELEASE_NAME'? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_msg "$YELLOW" "⚠️  已取消"
        exit 0
    fi
    
    # 执行卸载
    helm uninstall "$RELEASE_NAME" --namespace "$NAMESPACE"
    
    print_msg "$GREEN" "✅ SLURM Chart 已卸载"
}

# 函数: 显示状态
show_status() {
    print_title "Helm Release 状态"
    helm status "$RELEASE_NAME" --namespace "$NAMESPACE"
    
    echo ""
    print_title "Pod 状态"
    kubectl get pods -n "$NAMESPACE"
    
    echo ""
    print_title "Service 状态"
    kubectl get svc -n "$NAMESPACE"
}

# 函数: 显示帮助
show_help() {
    cat << EOF
SLURM Helm Chart 快速部署脚本

用法: $0 <命令> [选项]

命令:
  install      - 安装 SLURM Chart
  upgrade      - 升级现有的 SLURM deployment
  uninstall    - 卸载 SLURM Chart
  verify       - 验证 Chart 语法（helm lint）
  template     - 生成并显示 Kubernetes 资源模板
  dry-run      - 模拟部署（测试配置）
  status       - 显示部署状态

选项:
  --namespace   - 指定 Kubernetes 命名空间 (默认: slurm)
  --release     - 指定 release 名称 (默认: slurm)
  --values      - 指定自定义 values 文件

环境变量:
  SLURM_NAMESPACE     - Kubernetes 命名空间 (默认: slurm)
  SLURM_RELEASE_NAME  - Release 名称 (默认: slurm)

示例:
  # 快速安装
  $0 install

  # 验证 Chart
  $0 verify

  # 生成模板（不部署）
  $0 template

  # 模拟部署
  $0 dry-run

  # 查看部署状态
  $0 status

  # 升级
  $0 upgrade

  # 卸载
  $0 uninstall

  # 使用自定义 namespace
  SLURM_NAMESPACE=my-slurm $0 install

更多信息请查看:
  - README.md          - 主文档
  - USAGE_EXAMPLES.md  - 使用示例
  - INDEX.md           - 快速导航

EOF
}

# 主程序
main() {
    local command="${1:-install}"
    
    case "$command" in
        install)
            check_prerequisites
            verify_chart
            install
            ;;
        upgrade)
            check_prerequisites
            verify_chart
            upgrade
            ;;
        uninstall)
            uninstall
            ;;
        verify)
            verify_chart
            ;;
        template|gen)
            show_template
            ;;
        dry-run|test)
            check_prerequisites
            verify_chart
            dry_run
            ;;
        status)
            show_status
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_msg "$RED" "❌ 未知的命令: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# 运行主程序
main "$@"
