cat << 'EOF_DEVSTACK_SCRIPT' > /home/ubuntu/devstack.sh
#!/bin/bash
set -euo pipefail # 遇到錯誤即退出，使用未設置的變量即退出，管道命令失敗即退出

# --- 1. 用戶管理及 Sudo 權限配置 ---
USERNAME="stack"
HOME_DIR="/home/$USERNAME"
SUDOERS_FILE="/etc/sudoers.d/$USERNAME"

echo "==== 配置用戶 '$USERNAME' ===="

# 檢查用戶是否存在，如果不存在則創建
if id -u "$USERNAME" >/dev/null 2>&1; then
    echo "用戶 '$USERNAME' 已存在，跳過創建。"
else
    echo "正在創建用戶 '$USERNAME'..."
    # -m: 創建家目錄
    # -s /bin/bash: 設定默認 shell 為 bash
    useradd -m -s /bin/bash "$USERNAME"
    echo "用戶 '$USERNAME' 創建成功。"
fi

# 確保家目錄存在且所有權正確
mkdir -p "$HOME_DIR"
chown "$USERNAME:$USERNAME" "$HOME_DIR"

# 配置 sudo 權限 (NOPASSWD 和 !requiretty)
echo "正在為用戶 '$USERNAME' 配置 sudo 權限..."
if [ -f "$SUDOERS_FILE" ]; then
    echo "sudoers 文件 '$SUDOERS_FILE' 已存在，跳過創建。"
else
    # 寫入 sudoers 配置，允許免密碼執行所有命令，並禁用 requiretty
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" | sudo tee "$SUDOERS_FILE" > /dev/null
    echo "Defaults:$USERNAME !requiretty" | sudo tee -a "$SUDOERS_FILE" > /dev/null
    # 設定正確的權限
    sudo chmod 0440 "$SUDOERS_FILE"
    echo "sudo 權限配置完成。"
fi

# --- 2. 創建並填充 start.sh 腳本 ---
START_SCRIPT_PATH="$HOME_DIR/start.sh"

echo "==== 創建 '$START_SCRIPT_PATH' ===="

# 將 start.sh 的內容直接寫入文件
# 使用 'EOF_START_SCRIPT' 確保內容中的變量不會被主腳本展開
cat << 'EOF_START_SCRIPT' > "$START_SCRIPT_PATH"
#!/bin/bash
set -euo pipefail

echo "INFO: Running start.sh as user $(whoami)"

# 設定 GIT_BRANCH，如果未設定則預設為 master
GIT_BRANCH="${GIT_BRANCH:-master}"
echo "INFO: 將克隆 DevStack 分支: $GIT_BRANCH"

# 檢測包管理器 (apt 或 dnf)
PKG_MANAGER=""
if command -v apt-get &> /dev/null; then
    PKG_MANAGER="apt"
elif command -v dnf &> /dev/null; then
    PKG_MANAGER="dnf"
else
    echo "ERROR: 未找到支持的包管理器 (apt 或 dnf)。"
    exit 1
fi

echo "INFO: 使用包管理器: $PKG_MANAGER"

# 更新系統包
echo "INFO: 正在更新系統包..."
if [ "$PKG_MANAGER" == "apt" ]; then
    DEBIAN_FRONTEND=noninteractive sudo apt-get -qqy update
elif [ "$PKG_MANAGER" == "dnf" ]; then
    sudo dnf update -qy
fi
echo "INFO: 系統包更新完成。"

# 安裝 git
echo "INFO: 正在安裝 git..."
if [ "$PKG_MANAGER" == "apt" ]; then
    DEBIAN_FRONTEND=noninteractive sudo apt-get install -qqy git
elif [ "$PKG_MANAGER" == "dnf" ]; then
    sudo dnf install -qy git
fi
echo "INFO: git 安裝完成。"

# 確保 /home/stack 的所有權正確 (即使主腳本已設置，這裡也保留一份以增加健壯性)
sudo chown "$(whoami)":"$(whoami)" "/home/$(whoami)"

# 克隆 DevStack 倉庫
cd "/home/$(whoami)"
if [ ! -d "devstack" ]; then
    echo "INFO: 正在克隆 DevStack 倉庫 (分支: $GIT_BRANCH)..."
    git clone -b "$GIT_BRANCH" https://opendev.org/openstack/devstack
else
    echo "INFO: DevStack 倉庫已存在，跳過克隆。"
    echo "INFO: 檢查當前分支，並嘗試切換到 '$GIT_BRANCH'..."
    cd devstack
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    if [ "$CURRENT_BRANCH" != "$GIT_BRANCH" ]; then
        echo "WARNING: 當前分支是 '$CURRENT_BRANCH'，與目標分支 '$GIT_BRANCH' 不同。"
        echo "嘗試切換到 '$GIT_BRANCH' 並拉取最新代碼..."
        git fetch origin
        git checkout "$GIT_BRANCH"
        git pull origin "$GIT_BRANCH"
    else
        echo "INFO: 當前分支已是 '$GIT_BRANCH'，拉取最新代碼..."
        git pull origin "$GIT_BRANCH"
    fi
    cd .. # 返回 /home/stack
fi

cd devstack

# 創建 local.conf
echo "INFO: 正在創建 local.conf..."
cat << EOF_LOCAL_CONF > local.conf
[[local|localrc]]
ADMIN_PASSWORD=password
DATABASE_PASSWORD=password
RABBIT_PASSWORD=password
SERVICE_PASSWORD=password

# enable LDAP backend keystone
#enable_service ldap
#LDAP_PASSWORD=password

EOF_LOCAL_CONF
echo "INFO: local.conf 創建完成。"

# 運行 stack.sh
echo "INFO: 正在運行 stack.sh (這可能需要很長時間)..."
./stack.sh
echo "INFO: stack.sh 執行完成。"

EOF_START_SCRIPT

# 設定 start.sh 的所有者和執行權限
chown "$USERNAME:$USERNAME" "$START_SCRIPT_PATH"
chmod 0755 "$START_SCRIPT_PATH"
echo "'$START_SCRIPT_PATH' 創建成功並設置了權限。"

# --- 3. 以 'stack' 用戶身份執行 start.sh ---
echo "==== 以用戶 '$USERNAME' 身份執行 '$START_SCRIPT_PATH' ===="
# 使用 su -l 來模擬登錄 shell，確保環境變量正確，並傳遞 GIT_BRANCH
# 如果您想指定分支，可以在此處設置，例如：
# su -l "$USERNAME" -c "GIT_BRANCH=stable/yoga $START_SCRIPT_PATH"
su -l "$USERNAME"   -c "GIT_BRANCH=stable/2025.1 $START_SCRIPT_PATH"
echo "主腳本執行完成。"
EOF_DEVSTACK_SCRIPT

echo "文件 'devstack.sh' 已創建成功。"



chmod +x /home/ubuntu/devstack.sh
sudo /home/ubuntu/devstack.sh
