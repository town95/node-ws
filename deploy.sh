#!/bin/bash
set -e

# ========== 自动获取当前用户名 ==========
cd ~ || { echo "❌ 无法切换到主目录"; exit 1; }
path="$(pwd)"
USERNAME="${path#/home/}"
USERNAME="${USERNAME%%/*}"

echo "自动检测当前用户名: $USERNAME"

# ========== 手动输入域名 ==========
read -p "请输入绑定的域名（如 us.example.com）: " DOMAIN
if [ -z "$DOMAIN" ]; then
    echo "❌ 域名不能为空，脚本退出。"
    exit 1
fi

# ========== 配置 ==========
APP_ROOT="/home/$USERNAME/domains/$DOMAIN/public_html"
NODE_VERSION="22.14.0"
NODE_ENV_VERSION="22"
STARTUP_FILE="index.js"
NODE_VENV_BIN="/home/$USERNAME/nodevenv/domains/$DOMAIN/public_html/$NODE_ENV_VERSION/bin"
LOG_DIR="/home/$USERNAME/.npm/_logs"

# ========== 执行逻辑 ==========
echo "📁 切换目录到 $APP_ROOT"
cd "$APP_ROOT" || { echo "❌ 目录不存在: $APP_ROOT"; exit 1; }

echo "📄 复制 cloudlinux-selector 到当前目录为 cf"
cp /usr/sbin/cloudlinux-selector ./cf

echo "🗑️ 尝试销毁旧 Node.js 环境（若存在）"
./cf destroy \
  --json \
  --interpreter=nodejs \
  --user="$USERNAME" \
  --app-root="$APP_ROOT" || echo "⚠️ 旧环境可能不存在，跳过销毁"

echo "📥 下载并执行 setup.sh 初始化"
curl -Ls https://raw.githubusercontent.com/town95/node-ws/main/setup.sh -o setup.sh
chmod +x setup.sh
./setup.sh "$DOMAIN"

echo "⚙️ 创建 Node.js 新环境"
./cf create \
  --json \
  --interpreter=nodejs \
  --user="$USERNAME" \
  --app-root="$APP_ROOT" \
  --app-uri="/" \
  --version="$NODE_VERSION" \
  --app-mode=Production \
  --startup-file="$STARTUP_FILE"

echo "📦 安装依赖 via npm"
"$NODE_VENV_BIN/npm" install

echo "🧹 清理 NPM 安装日志"
if [ -d "$LOG_DIR" ]; then
  ls "$LOG_DIR"
  rm -f "$LOG_DIR"/*.log
else
  echo "📂 日志目录不存在，跳过删除"
fi

echo "✅ 部署完成，Node.js 应用已成功设置"
