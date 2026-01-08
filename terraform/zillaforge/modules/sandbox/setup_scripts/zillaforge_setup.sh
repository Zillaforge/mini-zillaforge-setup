# 請確保您當前執行的用戶有寫入 /home/ubuntu 的權限。
# 如果您不是 ubuntu 用戶或 root，可能需要使用 sudo：
# sudo cat << 'EOF' > /home/ubuntu/auto_zillaforge_setup.sh
cat << 'EOF' > /home/ubuntu/auto_zillaforge_setup.sh
#!/bin/bash

# 設定：任何指令失敗時立即退出
set -e

# --- 函數：安裝 expect ---
install_expect() {
    echo "未找到 expect。嘗試安裝 expect..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y expect
    elif command -v yum &> /dev/null; then
        sudo yum install -y expect
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y expect
    else
        echo "錯誤：找不到適合的套件管理器 (apt-get, yum, dnf) 來安裝 expect。"
        echo "請手動安裝 expect (例如：sudo apt-get install expect) 後再重新執行此腳本。"
        exit 1
    fi

    if ! command -v expect &> /dev/null; then
        echo "錯誤：expect 安裝失敗。請手動安裝。"
        exit 1
    fi
    echo "expect 安裝成功。"
}

# --- 步驟 1: 檢查並安裝 expect ---
echo "檢查 expect 工具..."
if ! command -v expect &> /dev/null; then
    install_expect
else
    echo "expect 已安裝。"
fi

# --- 步驟 2: 複製儲存庫到 /home/ubuntu ---
REPO_URL="https://github.com/Zillaforge/mini-zillaforge-setup.git"
REPO_NAME="mini-zillaforge-setup" # 儲存庫的目錄名稱
CLONE_TARGET_DIR="/home/ubuntu"
FULL_REPO_PATH="$CLONE_TARGET_DIR/$REPO_NAME" # 完整的儲存庫路徑

# 檢查目標目錄是否存在且可寫入
if [ ! -d "$CLONE_TARGET_DIR" ]; then
    echo "錯誤：目標目錄 $CLONE_TARGET_DIR 不存在。請確認該目錄是否存在且有權限。"
    exit 1
fi

# 切換到目標目錄
echo "正在切換到 $CLONE_TARGET_DIR 目錄以進行複製..."
cd "$CLONE_TARGET_DIR" || { echo "錯誤：無法進入目錄 $CLONE_TARGET_DIR。請檢查權限。"; exit 1; }

# 檢查儲存庫是否已存在
if [ -d "$REPO_NAME" ]; then
    echo "目錄 $FULL_REPO_PATH 已存在。正在進入並拉取最新更改..."
    cd "$REPO_NAME" || { echo "錯誤：無法進入目錄 $REPO_NAME (在 $CLONE_TARGET_DIR 內)。"; exit 1; }
    git pull || { echo "錯誤：無法拉取最新更改。"; exit 1; }
else
    echo "正在複製 $REPO_URL 儲存庫到 $CLONE_TARGET_DIR..."
    git clone "$REPO_URL" || { echo "錯誤：無法複製儲存庫到 $CLONE_TARGET_DIR。"; exit 1; }
    cd "$REPO_NAME" || { echo "錯誤：無法進入目錄 $REPO_NAME (在 $CLONE_TARGET_DIR 內)。"; exit 1; }
fi

# 現在腳本的當前工作目錄應該是 /home/ubuntu/mini-zillaforge-setup

# --- 步驟 3: 更新子模組 ---
echo "正在更新子模組..."
git submodule update --init --recursive || { echo "錯誤：無法更新子模組。"; exit 1; }

# --- 步驟 4: 準備 expect 腳本來處理 prerequisite.sh ---
# 建立一個臨時的 expect 腳本，用於自動回應提示
EXPECT_SCRIPT_NAME="auto_prerequisite.exp"
cat << 'EOF_EXPECT_SCRIPT' > "$EXPECT_SCRIPT_NAME"
#!/usr/bin/expect -f
set timeout -1
spawn ./prerequisite.sh
expect "Do you want to use fully automatic install prerequisites? (y/n):"
send "y\r"
expect eof
EOF_EXPECT_SCRIPT
chmod +x "$EXPECT_SCRIPT_NAME" || { echo "錯誤：無法使 expect 腳本可執行。"; exit 1; }

# --- 步驟 5: 使用 expect 執行 prerequisite.sh ---
echo "正在執行 prerequisite.sh，並自動回應 'y'..."
./"$EXPECT_SCRIPT_NAME" || { echo "錯誤：prerequisite.sh (透過 expect) 執行失敗。"; exit 1; }

# 移除臨時的 expect 腳本
rm -f "$EXPECT_SCRIPT_NAME"

# --- 步驟 6: 載入 ~/.bashrc ---
echo "正在載入 ~/.bashrc..."
# 注意：在腳本中載入 .bashrc 只會影響此腳本的環境。
# 如果要在腳本完成後影響您當前的終端機會話，您可能需要手動執行 'source ~/.bashrc'
# 或開啟一個新的終端機。此步驟是按照您的要求包含的，假設後續指令可能依賴於
# prerequisite.sh 透過 .bashrc 設定的環境變數。
source ~/.bashrc

# --- 步驟 7: 執行 install.sh ---
echo "正在執行 install.sh..."
./install.sh || { echo "錯誤：install.sh 執行失敗。"; exit 1; }

# --- 步驟 8: 執行 post-configuration.sh ---
echo "正在執行 post-configuration.sh..."
./post-configuration.sh || { echo "錯誤：post-configuration.sh 執行失敗。"; exit 1; }

echo "---------------------------------------------------------"
echo "所有安裝與配置步驟已成功完成！"
echo "請注意，所有操作都在 $FULL_REPO_PATH 目錄下完成。"
echo "如果環境變數有更新 (例如：PATH)，您可能需要："
echo "  1. 開啟一個新的終端機會話，或者"
echo "  2. 在當前的終端機中手動執行 'source ~/.bashrc'。"
echo "---------------------------------------------------------"
EOF

chmod +x /home/ubuntu/auto_zillaforge_setup.sh
su -l ubuntu -c 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml; /home/ubuntu/auto_zillaforge_setup.sh'
