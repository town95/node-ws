#!/bin/bash
set -e

# ========== 第一步：自动检测用户名 ==========
cd ~ || { echo "❌ 无法切换到主目录"; exit 1; }
USERNAME="$(basename "$PWD")"
echo "🧑 当前用户名: $USERNAME"

# ========== 第二步：输入域名 ==========
read -p "请输入绑定的域名（如 us.example.com）: " DOMAIN
if [ -z "$DOMAIN" ]; then
    echo "❌ 域名不能为空，脚本退出。"
    exit 1
fi

# ========== 第三步：输入 UUID ==========
read -p "请输入 UUID（用于 WebSocket 鉴权）: " UUID
if [ -z "$UUID" ]; then
    echo "❌ UUID 不能为空，脚本退出。"
    exit 1
fi

# ========== 探针可选项 ==========
read -p "是否安装哪吒探针？[y/n] [n]: " input
input=${input:-n}
if [ "$input" != "n" ]; then
  read -p "输入 NEZHA_SERVER（如 nz.xxx.com:5555）: " nezha_server
  [ -z "$nezha_server" ] && { echo "❌ NEZHA_SERVER 不能为空"; exit 1; }

  read -p "输入 NEZHA_PORT（v1留空，v0用443/2096等）: " nezha_port
  read -p "输入 NEZHA_KEY（v1面板为 NZ_CLIENT_SECRET）: " nezha_key
  [ -z "$nezha_key" ] && { echo "❌ NEZHA_KEY 不能为空"; exit 1; }
fi

# ========== 基础路径设置 ==========
APP_ROOT="/home/$USERNAME/domains/$DOMAIN/public_html"
NODE_VERSION="22.14.0"
NODE_ENV_VERSION="22"
STARTUP_FILE="index.js"
NODE_VENV_BIN="/home/$USERNAME/nodevenv/domains/$DOMAIN/public_html/$NODE_ENV_VERSION/bin"
LOG_DIR="/home/$USERNAME/.npm/_logs"
RANDOM_PORT=$((RANDOM % 40001 + 20000))

# ========== 第四步：准备目录 ==========
echo "📁 创建应用目录: $APP_ROOT"
mkdir -p "$APP_ROOT"
cd "$APP_ROOT" || { echo "❌ 切换目录失败"; exit 1; }

# ========== 下载主程序 ==========
echo "📥 下载 index.js 和 cron.sh,下载ttyd"
curl -s -o "$APP_ROOT/index.js" "https://raw.githubusercontent.com/TownMarshal/node-ws/main/index.js"
curl -s -o "/home/$USERNAME/cron.sh" "https://raw.githubusercontent.com/TownMarshal/node-ws/main/cron.sh"
chmod +x /home/$USERNAME/cron.sh

wget "https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64"
mv ttyd.x86_64 ttyd   
chmod +x ttyd       

# ========== 替换变量 ==========
sed -i "s/1234.abc.com/$DOMAIN/g" "$APP_ROOT/index.js"
sed -i "s/3000;/$RANDOM_PORT;/g" "$APP_ROOT/index.js"
sed -i "s/de04add9-5c68-6bab-950c-08cd5320df33/$UUID/g" "$APP_ROOT/index.js"

# 探针变量替换
if [ "$input" = "y" ]; then
  sed -i "s/NEZHA_SERVER || ''/NEZHA_SERVER || '$nezha_server'/g" "$APP_ROOT/index.js"
  sed -i "s/NEZHA_PORT || ''/NEZHA_PORT || '$nezha_port'/g" "$APP_ROOT/index.js"
  sed -i "s/NEZHA_KEY || ''/NEZHA_KEY || '$nezha_key'/g" "$APP_ROOT/index.js"
  sed -i "s/nezha_check=false/nezha_check=true/g" "/home/$USERNAME/cron.sh"
fi

# ========== 写入 package.json ==========
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

# ========== 配置 CloudLinux Node 环境 ==========
echo "📄 复制 cloudlinux-selector 为本地 cf 命令"
cp /usr/sbin/cloudlinux-selector ./cf

echo "🗑️ 尝试销毁旧环境（如存在）"
./cf destroy \
  --json \
  --interpreter=nodejs \
  --user="$USERNAME" \
  --app-root="$APP_ROOT" || echo "⚠️ 无旧环境，跳过"

echo "⚙️ 创建新 Node 环境"
./cf create \
  --json \
  --interpreter=nodejs \
  --user="$USERNAME" \
  --app-root="$APP_ROOT" \
  --app-uri="/" \
  --version="$NODE_VERSION" \
  --app-mode=Production \
  --startup-file="$STARTUP_FILE"

# ========== 安装依赖 ==========
echo "📦 安装依赖 via npm"
"$NODE_VENV_BIN/npm" install

# ========== 清理日志 ==========
echo "🧹 清理 npm 日志"
[ -d "$LOG_DIR" ] && rm -f "$LOG_DIR"/*.log || echo "📂 无日志目录，跳过"

# ========== 写入 start_ttyd.sh ==========
cat > "$APP_ROOT/start_ttyd.sh" << 'EOF'
#!/bin/bash
# ============ 配置参数 ============
PORT=35000
CMD_PATH="$APP_ROOT/ttyd"   # ============修改 ============
AUTH="town:ts521"
LOGFILE="$APP_ROOT/ttyd.log"  # ============修改 ============
MAX_SIZE=10485760  # 10MB = 10 * 1024 * 1024 bytes
# ============ 清理超大日志 ============
if [ -f "$LOGFILE" ]; then
    FILESIZE=$(stat -c%s "$LOGFILE")
    if [ "$FILESIZE" -ge "$MAX_SIZE" ]; then
        echo "$(date): Log file exceeded 10MB, clearing..." > "$LOGFILE"
    fi
fi
# ============ 检查是否运行 ============
if ! pgrep -f "$CMD_PATH" > /dev/null; then
    echo "$(date): ttyd not running, starting..." >> "$LOGFILE"
    setsid "$CMD_PATH" -p "$PORT" -c "$AUTH" -W bash >> "$LOGFILE" 2>&1 &
else
    echo "$(date): ttyd is running" >> "$LOGFILE"
fi
EOF

chmod +x "$APP_ROOT/start_ttyd.sh"
echo "✅ 脚本创建成功：$APP_ROOT/start_ttyd.sh"
echo "💡 建议添加到 crontab 定时任务中运行："
echo "*/2 * * * * $APP_ROOT/start_ttyd.sh"

# ========== start_ttyd.sh设置定时任务 ==========
echo "⏱️ 写入 crontab 每两分钟执行一次 start_ttyd.sh"
echo "*/2 * * * * $APP_ROOT/start_ttyd.sh" > ./start_ttyd
crontab ./start_ttyd >/dev/null 2>&1
rm ./start_ttyd

# ========== 设置定时任务 ==========
echo "⏱️ 写入 crontab 每分钟执行一次 cron.sh"
echo "*/1 * * * * cd /home/$USERNAME/public_html && /home/$USERNAME/cron.sh" > ./mycron
crontab ./mycron >/dev/null 2>&1
rm ./mycron

# ========== 结束提示 ==========
echo "✅ 应用部署完成！"
echo "🌐 域名: $DOMAIN"
echo "🧾 UUID: $UUID"
echo "📡 本地监听端口: $RANDOM_PORT"
[ "$input" = "y" ] && echo "📟 哪吒探针已配置: $nezha_server"

# ========== 自毁脚本 ==========
rm -- "$0"
