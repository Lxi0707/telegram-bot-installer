```bash
#!/bin/bash

# Telegram 机器人管理脚本
# 基于交互式设计的最佳实践

# 配置路径
CONFIG_FILE="/root/telegram-bot/bot_config.py"
INSTALL_DIR="/root/telegram-bot"
SERVICE_FILE="/etc/systemd/system/telegram-bot.service"

# 颜色设置
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
PURPLE="\033[35m"
CYAN="\033[36m"
WHITE="\033[37m"
BOLD="\033[1m"
RESET="\033[0m"

# 调试模式
DEBUG=false

# 显示菜单
show_menu() {
    clear
    echo -e "${BOLD}${CYAN}=================================${RESET}"
    echo -e "${BOLD}${CYAN}    Telegram 机器人管理脚本     ${RESET}"
    echo -e "${BOLD}${CYAN}=================================${RESET}"
    echo -e " ${GREEN}1${RESET}. 安装机器人"
    echo -e " ${GREEN}2${RESET}. 配置参数"
    echo -e " ${YELLOW}3${RESET}. 查看配置"
    echo -e " ${YELLOW}4${RESET}. 启动服务"
    echo -e " ${YELLOW}5${RESET}. 停止服务"
    echo -e " ${YELLOW}6${RESET}. 重启服务"
    echo -e " ${YELLOW}7${RESET}. 查看状态"
    echo -e " ${RED}8${RESET}. 卸载机器人"
    echo -e " ${BLUE}9${RESET}. 生成脚本"
    echo -e " ${RED}0${RESET}. 退出脚本"
    echo -e "${BOLD}${CYAN}=================================${RESET}"
    
    while true; do
        read -p "请输入选择 [0-9]: " choice
        case $choice in
            [0-9]) break ;;
            *) echo -e "${RED}无效输入，请重新选择${RESET}" ;;
        esac
    done
}

# 读取配置
read_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        BOT_TOKEN=$(grep "BOT_TOKEN" "$CONFIG_FILE" 2>/dev/null | cut -d'"' -f2)
        ADMIN_USER_ID=$(grep "ADMIN_USER_ID" "$CONFIG_FILE" 2>/dev/null | grep -Eo '[0-9]+')
        GROUP_CHAT_ID=$(grep "GROUP_CHAT_ID" "$CONFIG_FILE" 2>/dev/null | grep -Eo '-?[0-9]+')
    else
        BOT_TOKEN=""
        ADMIN_USER_ID=""
        GROUP_CHAT_ID=""
    fi
}

# 配置参数
configure_bot() {
    echo -e "\n${BOLD}${BLUE}⚙️  配置机器人参数${RESET}"
    echo -e "${CYAN}────────────────────────────${RESET}"
    
    read_config
    
    # 获取输入
    read -p "请输入 BOT_TOKEN: " new_token
    read -p "请输入管理员用户ID: " new_admin
    read -p "请输入群组ID: " new_group
    
    # 验证输入
    if [[ -z "$new_token" || -z "$new_admin" || -z "$new_group" ]]; then
        echo -e "${RED}❌ 所有字段都必须填写！${RESET}"
        sleep 2
        return 1
    fi
    
    # 创建目录
    mkdir -p "$(dirname "$CONFIG_FILE")"
    
    # 写入配置
    cat > "$CONFIG_FILE" << EOF
# 机器人配置
BOT_TOKEN = "$new_token"
ADMIN_USER_ID = $new_admin
GROUP_CHAT_ID = $new_group
DATABASE_NAME = "bot_usage.db"
EOF
    
    echo -e "${GREEN}✅ 配置已保存到: $CONFIG_FILE${RESET}"
    sleep 2
    return 0
}

# 安装机器人
install_bot() {
    echo -e "\n${BOLD}${GREEN}🚀 安装机器人${RESET}"
    echo -e "${CYAN}────────────────────────────${RESET}"
    
    # 检查配置
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${YELLOW}⚠️  尚未配置，先进行配置...${RESET}"
        configure_bot
        if [[ ! -f "$CONFIG_FILE" ]]; then
            echo -e "${RED}❌ 配置未完成，安装取消${RESET}"
            sleep 2
            return 1
        fi
    fi
    
    read_config
    echo -e "${YELLOW}使用配置:"
    echo -e "BOT_TOKEN: ***"
    echo -e "ADMIN_ID: $ADMIN_USER_ID"
    echo -e "GROUP_ID: $GROUP_CHAT_ID${RESET}"
    echo ""
    
    read -p "确认安装？(y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${YELLOW}安装取消${RESET}"
        sleep 1
        return 1
    fi
    
    # 安装依赖
    echo -e "${BLUE}📦 安装系统依赖...${RESET}"
    apt update && apt install -y python3 python3-pip python3-venv git
    
    # 创建目录
    echo -e "${BLUE}📁 创建项目目录...${RESET}"
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR" || return 1
    
    # 创建虚拟环境
    echo -e "${BLUE}🐍 创建虚拟环境...${RESET}"
    python3 -m venv bot-env
    
    # 安装Python包
    echo -e "${BLUE}📦 安装Python包...${RESET}"
    source bot-env/bin/activate
    pip install python-telegram-bot
    deactivate
    
    # 创建主程序
    create_main_program
    
    # 创建启动脚本
    create_start_script
    
    # 创建系统服务
    create_systemd_service
    
    echo -e "${GREEN}✅ 安装完成！${RESET}"
    echo -e "${YELLOW}使用命令启动: systemctl start telegram-bot${RESET}"
    sleep 3
}

# 创建主程序
create_main_program() {
    cat > "$INSTALL_DIR/telegram_bot.py" << 'EOF'
import logging
import sqlite3
from datetime import datetime
from telegram import Update
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes

from bot_config import BOT_TOKEN, ADMIN_USER_ID, GROUP_CHAT_ID, DATABASE_NAME

# 设置日志
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

def init_database():
    conn = sqlite3.connect(DATABASE_NAME)
    cursor = conn.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS user_usage (
            user_id INTEGER PRIMARY KEY,
            username TEXT,
            first_name TEXT,
            last_name TEXT,
            usage_count INTEGER DEFAULT 0,
            first_used TIMESTAMP,
            last_used TIMESTAMP
        )
    ''')
    conn.commit()
    conn.close()

def record_user_usage(user_id, username, first_name, last_name):
    conn = sqlite3.connect(DATABASE_NAME)
    cursor = conn.cursor()
    now = datetime.now()
    
    cursor.execute("SELECT usage_count FROM user_usage WHERE user_id = ?", (user_id,))
    user = cursor.fetchone()
    
    if user:
        cursor.execute('''
            UPDATE user_usage SET usage_count = usage_count + 1, 
            last_used = ?, username = ?, first_name = ?, last_name = ?
            WHERE user_id = ?
        ''', (now, username, first_name, last_name, user_id))
    else:
        cursor.execute('''
            INSERT INTO user_usage 
            (user_id, username, first_name, last_name, usage_count, first_used, last_used)
            VALUES (?, ?, ?, ?, 1, ?, ?)
        ''', (user_id, username, first_name, last_name, now, now))
    
    conn.commit()
    conn.close()

async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    await update.message.reply_text(f"你好 {user.first_name}！欢迎使用消息转发机器人。")

async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    message = update.message
    
    record_user_usage(user.id, user.username, user.first_name, user.last_name)
    
    forward_text = f"来自用户: {user.first_name}"
    if user.username:
        forward_text += f" @{user.username}"
    forward_text += f"\n用户ID: {user.id}\n\n消息内容:\n{message.text}"
    
    try:
        await context.bot.send_message(chat_id=GROUP_CHAT_ID, text=forward_text)
        await message.reply_text("消息已转发！")
    except Exception as e:
        logger.error(f"发送消息错误: {e}")
        await message.reply_text("发送失败，请检查配置。")

async def stats_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    if user.id != ADMIN_USER_ID:
        await update.message.reply_text("无权限")
        return
    
    await update.message.reply_text("统计功能待实现")

async def error_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    logger.error(f"错误: {context.error}")

def main():
    init_database()
    application = Application.builder().token(BOT_TOKEN).build()
    
    application.add_handler(CommandHandler("start", start_command))
    application.add_handler(CommandHandler("stats", stats_command))
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
    application.add_error_handler(error_handler)
    
    logger.info("机器人启动中...")
    application.run_polling()

if __name__ == "__main__":
    main()
EOF
}

# 创建启动脚本
create_start_script() {
    cat > "$INSTALL_DIR/start_bot.sh" << 'EOF'
#!/bin/bash
cd /root/telegram-bot
source /root/telegram-bot/bot-env/bin/activate
python /root/telegram-bot/telegram_bot.py
EOF
    chmod +x "$INSTALL_DIR/start_bot.sh"
}

# 创建系统服务
create_systemd_service() {
    cat > /tmp/telegram-bot.service << EOF
[Unit]
Description=Telegram Message Forwarding Bot
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/telegram-bot
ExecStart=/root/telegram-bot/start_bot.sh
Restart=always
RestartSec=5
Environment=PATH=/root/telegram-bot/bot-env/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

[Install]
WantedBy=multi-user.target
EOF
    
    mv /tmp/telegram-bot.service "$SERVICE_FILE"
    systemctl daemon-reload
    systemctl enable telegram-bot
}

# 启动服务
start_service() {
    echo -e "\n${BOLD}${GREEN}▶️  启动服务${RESET}"
    systemctl start telegram-bot
    sleep 2
    check_service_status
}

# 停止服务
stop_service() {
    echo -e "\n${BOLD}${RED}⏹️  停止服务${RESET}"
    systemctl stop telegram-bot
    sleep 1
    check_service_status
}

# 重启服务
restart_service() {
    echo -e "\n${BOLD}${YELLOW}🔄 重启服务${RESET}"
    systemctl restart telegram-bot
    sleep 2
    check_service_status
}

# 检查服务状态
check_service_status() {
    if systemctl is-active --quiet telegram-bot; then
        echo -e "${GREEN}✅ 服务正在运行${RESET}"
    else
        echo -e "${RED}❌ 服务未运行${RESET}"
    fi
    sleep 2
}

# 查看状态
view_status() {
    echo -e "\n${BOLD}${BLUE}📊 服务状态${RESET}"
    echo -e "${CYAN}────────────────────────────${RESET}"
    systemctl status telegram-bot --no-pager -l
    echo ""
    read -p "按回车键继续..."
}

# 查看配置
view_config() {
    echo -e "\n${BOLD}${BLUE}📋 当前配置${RESET}"
    echo -e "${CYAN}────────────────────────────${RESET}"
    
    if [[ -f "$CONFIG_FILE" ]]; then
        echo -e "${GREEN}配置文件: $CONFIG_FILE${RESET}"
        echo ""
        echo "BOT_TOKEN = ***"
        grep -v "BOT_TOKEN" "$CONFIG_FILE" | grep -v "DATABASE_NAME"
    else
        echo -e "${RED}❌ 配置文件不存在${RESET}"
    fi
    
    echo ""
    check_service_status
    read -p "按回车键继续..."
}

# 卸载机器人
uninstall_bot() {
    echo -e "\n${BOLD}${RED}🗑️  卸载机器人${RESET}"
    echo -e "${CYAN}────────────────────────────${RESET}"
    
    read -p "确认卸载？(y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${YELLOW}卸载取消${RESET}"
        sleep 1
        return
    fi
    
    systemctl stop telegram-bot 2>/dev/null
    systemctl disable telegram-bot 2>/dev/null
    rm -f "$SERVICE_FILE"
    systemctl daemon-reload
    
    read -p "删除项目文件？(y/N): " delete_files
    if [[ "$delete_files" == "y" || "$delete_files" == "Y" ]]; then
        rm -rf "$INSTALL_DIR"
        echo -e "${GREEN}✅ 已删除所有文件${RESET}"
    else
        echo -e "${YELLOW}⚠️  保留项目文件${RESET}"
    fi
    
    echo -e "${GREEN}✅ 卸载完成${RESET}"
    sleep 2
}

# 生成安装脚本
generate_script() {
    echo -e "\n${BOLD}${BLUE}📜 生成安装脚本${RESET}"
    echo -e "${CYAN}────────────────────────────${RESET}"
    echo -e "${YELLOW}此功能待实现${RESET}"
    sleep 2
}

# 主循环
main() {
    while true; do
        show_menu
        
        case $choice in
            1) install_bot ;;
            2) configure_bot ;;
            3) view_config ;;
            4) start_service ;;
            5) stop_service ;;
            6) restart_service ;;
            7) view_status ;;
            8) uninstall_bot ;;
            9) generate_script ;;
            0)
                echo -e "${GREEN}再见！${RESET}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选择${RESET}"
                sleep 1
                ;;
        esac
    done
}

# 检查root权限
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}请使用root权限运行此脚本${RESET}"
    exit 1
fi

# 启动主程序
main
```
