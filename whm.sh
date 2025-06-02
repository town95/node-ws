#!/bin/bash
set -e

read -p "请输入您的用户名: " INPUT_USERNAME

if [ -z "$INPUT_USERNAME" ]; then
    echo "错误：未输入用户名。脚本将退出。"
    exit 1
fi

read -p "请输入您的域名: " INPUT_DOMAIN

if [ -z "$INPUT_DOMAIN" ]; then
    echo "错误：未输入域名。脚本将退出。"
    exit 1
fi

echo "将使用以下信息执行脚本："
echo "用户名: $INPUT_USERNAME"
echo "域名: $INPUT_DOMAIN"
echo ""
read -p "确认继续吗? (输入 'y' 继续, 其他任意键取消): " CONFIRMATION

if [[ "$CONFIRMATION" != "y" && "$CONFIRMATION" != "Y" ]]; then
    echo "操作已取消。"
    exit 0
fi

APP_PUBLIC_HTML_SUBDIR="public_html"
NODE_SELECTOR_VERSION="22.14.0"
NODE_ENV_PATH_VERSION="22" 
APP_STARTUP_FILE="index.js"

APP_ROOT_DIRECTORY="/home/${INPUT_USERNAME}/domains/${INPUT_DOMAIN}/${APP_PUBLIC_HTML_SUBDIR}"
NPM_COMMAND_PATH="/home/${INPUT_USERNAME}/nodevenv/domains/${INPUT_DOMAIN}/${APP_PUBLIC_HTML_SUBDIR}/${NODE_ENV_PATH_VERSION}/bin/npm"
NPM_LOG_DIRECTORY="/home/${INPUT_USERNAME}/.npm/_logs"
SELF_SCRIPT_PATH="/home/${INPUT_USERNAME}/whm.sh"

cloudlinux-selector create \
    --json \
    --interpreter=nodejs \
    --user="$INPUT_USERNAME" \
    --app-root="$APP_ROOT_DIRECTORY" \
    --app-uri="/" \
    --version="$NODE_SELECTOR_VERSION" \
    --app-mode="development" \
    --startup-file="$APP_STARTUP_FILE"

if [ -d "$APP_ROOT_DIRECTORY" ] && [ -f "$NPM_COMMAND_PATH" ] && [ -x "$NPM_COMMAND_PATH" ]; then
    ( 
        cd "$APP_ROOT_DIRECTORY" && "$NPM_COMMAND_PATH" install
    )

    echo "已安装。"
else
    echo "安装失败"
    # 如果希望在这种情况下脚本失败退出，可以取消下面一行的注释
    # exit 1
fi

if [ -d "$NPM_LOG_DIRECTORY" ]; then
    rm -f "${NPM_LOG_DIRECTORY}/"*.log
    echo "已删除log。"
else
    echo "日志目录 '${NPM_LOG_DIRECTORY}' 不存在。"
fi

if [ -f "$SELF_SCRIPT_PATH" ]; then
    rm -f "$SELF_SCRIPT_PATH"
    echo "执行成功。"
else
    echo "脚本文件 '${SELF_SCRIPT_PATH}' 未找到，无法删除。"
fi

