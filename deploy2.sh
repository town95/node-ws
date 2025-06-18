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

# ========== 获取当天日期 ==========
DATE_TAG=$(date +%F)  # YYYY-MM-DD
echo "📆 今日 SUB_PATH: $DATE_TAG"

# ========== 配置 ==========
APP_ROOT="/home/$USERNAME/domains/$DOMAIN/public_html"
NODE_VERSION="22.14.0"
NODE_ENV_VERSION="22"
STARTUP_FILE="index.js"
NODE_VENV_BIN="/home/$USERNAME/nodevenv/domains/$DOMAIN/public_html/$NODE_ENV_VERSION/bin"
LOG_DIR="/home/$USERNAME/.npm/_logs"

# ========== 创建 Node.js 项目结构 ==========
echo "📁 创建目录 $APP_ROOT"
mkdir -p "$APP_ROOT"
cd "$APP_ROOT"

# 下载 index2.js增加迷惑性
echo "📄 下载 index.js 到 $APP_ROOT"
curl -s -o "$APP_ROOT/index.js" "https://raw.githubusercontent.com/town95/node-ws/main/index2.js"
if [ $? -ne 0 ]; then
    echo "❌ 下载 index.js 失败，退出。"
    exit 1
fi

# 下载 cron.sh
curl -s -o "/home/$USERNAME/cron.sh" "https://raw.githubusercontent.com/town95/node-ws/main/cron.sh"
chmod +x "/home/$USERNAME/cron.sh"

# 用户交互输入
read -p "输入UUID: " UUID
[ -z "$UUID" ] && { echo "❌ UUID 不能为空"; exit 1; }

read -p "是否安装探针? [y/n] [n]: " INPUT
INPUT=${INPUT:-n}

if [ "$INPUT" != "n" ]; then
  read -p "输入 NEZHA_SERVER (nz.abc.com:8008 或 nz.abc.com): " NEZHA_SERVER
  [ -z "$NEZHA_SERVER" ] && { echo "❌ NEZHA_SERVER 不能为空"; exit 1; }
  read -p "输入 NEZHA_PORT (v1 留空，v0: 443 等): " NEZHA_PORT
  read -p "输入 NEZHA_KEY: " NEZHA_KEY
  [ -z "$NEZHA_KEY" ] && { echo "❌ NEZHA_KEY 不能为空"; exit 1; }
fi

# 替换 index.js 中相关参数
RANDOM_PORT=$((RANDOM % 40001 + 20000))

sed -i "s/NEZHA_SERVER || ''/NEZHA_SERVER || '$NEZHA_SERVER'/g" "$APP_ROOT/index.js"
sed -i "s/NEZHA_PORT || ''/NEZHA_PORT || '$NEZHA_PORT'/g" "$APP_ROOT/index.js"
sed -i "s/NEZHA_KEY || ''/NEZHA_KEY || '$NEZHA_KEY'/g" "$APP_ROOT/index.js"
sed -i "s/1234.abc.com/$DOMAIN/g" "$APP_ROOT/index.js"
sed -i "s/3000;/$RANDOM_PORT;/g" "$APP_ROOT/index.js"
sed -i "s/de04add9-5c68-6bab-950c-08cd5320df33/$UUID/g" "$APP_ROOT/index.js"

# 设置 SUB_PATH 为当前日期（核心变更）
sed -i "s|SUB_PATH || ''|SUB_PATH || '$DATE_TAG'|g" "$APP_ROOT/index.js"

if [ "$INPUT" = "y" ]; then
    sed -i "s/nezha_check=false/nezha_check=true/g" "/home/$USERNAME/cron.sh"
fi

# 写入 package.json
cat > "$APP_ROOT/package.json" << EOF
{
  "name": "node-ws",
  "version": "1.0.0",
  "description": "Node.js Server",
  "main": "index.js",
  "author": "eoovve",
  "repository": "https://github.com/eoovve/node-ws",
  "license": "MIT",
  "private": false,
  "scripts": {
    "start": "node index.js"
  },
  "dependencies": {
    "ws": "^8.14.2",
    "axios": "^1.6.2"
  },
  "engines": {
    "node": ">=14"
  }
}
EOF

# 添加 cron 定时任务
echo "*/1 * * * * cd /home/$USERNAME/public_html && /home/$USERNAME/cron.sh" > ./mycron
crontab ./mycron >/dev/null 2>&1
rm ./mycron

# ========== 开始 CloudLinux 环境部署 ==========
echo "📄 复制 cloudlinux-selector 到当前目录为 cf"
cp /usr/sbin/cloudlinux-selector ./cf

echo "🗑️ 尝试销毁旧 Node.js 环境（若存在）"
./cf destroy \
  --json \
  --interpreter=nodejs \
  --user="$USERNAME" \
  --app-root="$APP_ROOT" || echo "⚠️ 跳过销毁"

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

echo "🧹 清理日志"
if [ -d "$LOG_DIR" ]; then
  rm -f "$LOG_DIR"/*.log
else
  echo "日志目录不存在，跳过"
fi

echo "✅ 部署完成，Node.js 应用已设置为 /$DATE_TAG"
rm -- "$0"
