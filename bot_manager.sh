#!/bin/bash

# Telegram 机器人管理脚本
CONFIG_FILE="/root/telegram-bot/bot_config.py"
INSTALL_DIR="/root/telegram-bot"
SERVICE_FILE="/etc/systemd/system/telegram-bot.service"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 显示菜单
show_menu() {
    clear
    echo -e "${BLUE}=================================${NC}"
    echo -e "${BLUE}    Telegram 机器人管理脚本     ${NC}"
    echo -e "${BLUE}=================================${NC}"
    echo -e "1.  ${GREEN}安装机器人${NC}"
    echo -e "2.  ${GREEN}配置机器人参数${NC}"
    echo -e "3.  ${YELLOW}查看当前配置${NC}"
    echo -e "4.  ${YELLOW}启动机器人${NC}"
    echo -e "5.  ${YELLOW}停止机器人${NC}"
    echo -e "6.  ${YELLOW}重启机器人${NC}"
    echo -e "7.  ${YELLOW}查看运行状态${NC}"
    echo -e "8.  ${RED}卸载机器人${NC}"
    echo -e "9.  ${BLUE}生成安装脚本${NC}"
    echo -e "0.  ${RED}退出脚本${NC}"
    echo -e "${BLUE}=================================${NC}"
    
    read -p "请输入您的选择 [0-9]: " choice
}

# 读取当前配置
read_config() {
    if [ -f "$CONFIG_FILE" ]; then
        BOT_TOKEN=$(grep "BOT_TOKEN" "$CONFIG_FILE" | cut -d'"' -f2)
        ADMIN_USER_ID=$(grep "ADMIN_USER_ID" "$CONFIG_FILE" | grep -Eo '[0-9]+')
        GROUP_CHAT_ID=$(grep "GROUP_CHAT_ID" "$CONFIG_FILE" | grep -Eo '-?[0-9]+')
    else
        BOT_TOKEN=""
        ADMIN_USER_ID=""
        GROUP_CHAT_ID=""
    fi
}

# 配置参数
configure_bot() {
    clear
    echo -e "${BLUE}=== 配置机器人参数 ===${NC}"
    
    read_config
    
    # 获取当前值或设置默认值
    CURRENT_TOKEN=${BOT_TOKEN:-"8408900332:AAFmroWfxm46-kb-ab0PtjApP5TK3gSdg4M"}
    CURRENT_ADMIN=${ADMIN_USER_ID:-"6553906322"}
    CURRENT_GROUP=${GROUP_CHAT_ID:-"-1003009478386"}
    
    echo -e "当前配置:"
    echo -e "BOT_TOKEN: ${YELLOW}$CURRENT_TOKEN${NC}"
    echo -e "ADMIN_USER_ID: ${YELLOW}$CURRENT_ADMIN${NC}"
    echo -e "GROUP_CHAT_ID: ${YELLOW}$CURRENT_GROUP${NC}"
    echo ""
    
    read -p "请输入 BOT_TOKEN [$CURRENT_TOKEN]: " new_token
    read -p "请输入 ADMIN_USER_ID [$CURRENT_ADMIN]: " new_admin
    read -p "请输入 GROUP_CHAT_ID [$CURRENT_GROUP]: " new_group
    
    # 使用新值或保持原值
    new_token=${new_token:-$CURRENT_TOKEN}
    new_admin=${new_admin:-$CURRENT_ADMIN}
    new_group=${new_group:-$CURRENT_GROUP}
    
    # 创建配置目录
    mkdir -p "$INSTALL_DIR"
    
    # 写入配置文件
    cat > "$CONFIG_FILE" << EOL
# 机器人配置
BOT_TOKEN = "$new_token"
ADMIN_USER_ID = $new_admin
GROUP_CHAT_ID = $new_group
DATABASE_NAME = "bot_usage.db"
EOL
    
    echo -e "${GREEN}✅ 配置已保存!${NC}"
    sleep 2
}

# 查看配置
view_config() {
    clear
    echo -e "${BLUE}=== 当前配置 ===${NC}"
    
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${GREEN}配置文件: $CONFIG_FILE${NC}"
        echo ""
        cat "$CONFIG_FILE"
    else
        echo -e "${RED}❌ 配置文件不存在${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}=== 服务状态 ===${NC}"
    if systemctl is-active --quiet telegram-bot; then
        echo -e "${GREEN}✅ 机器人正在运行${NC}"
    else
        echo -e "${RED}❌ 机器人未运行${NC}"
    fi
    
    echo ""
    read -p "按回车键返回菜单..."
}

# 安装机器人
install_bot() {
    clear
    echo -e "${BLUE}=== 安装 Telegram 机器人 ===${NC}"
    
    # 检查是否已配置
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}❌ 请先配置机器人参数!${NC}"
        sleep 2
        configure_bot
    fi
    
    read_config
    
    echo -e "使用以下配置安装:"
    echo -e "BOT_TOKEN: ${YELLOW}$BOT_TOKEN${NC}"
    echo -e "ADMIN_USER_ID: ${YELLOW}$ADMIN_USER_ID${NC}"
    echo -e "GROUP_CHAT_ID: ${YELLOW}$GROUP_CHAT_ID${NC}"
    echo ""
    
    read -p "确认安装？(y/n): " confirm
    if [ "$confirm" != "y" ]; then
        echo -e "${YELLOW}安装取消${NC}"
        sleep 2
        return
    fi
    
    # 安装依赖
    echo -e "${BLUE}📦 安装系统
