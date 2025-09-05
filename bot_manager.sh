```bash
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
    echo ""
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
    
    echo -e "${YELLOW}请输入机器人配置信息：${NC}"
    echo ""
    
    # 获取输入，如果已有配置则显示提示
    if [ -n "$BOT_TOKEN" ]; then
        read -p "请输入 BOT_TOKEN [当前已设置]: " new_token
    else
        read -p "请输入 BOT_TOKEN: " new_token
    fi
    
    if [ -n "$ADMIN_USER_ID" ]; then
        read -p "请输入 ADMIN_USER_ID [当前: $ADMIN_USER_ID]: " new_admin
    else
        read -p "请输入 ADMIN_USER_ID: " new_admin
    fi
    
    if [ -n "$GROUP_CHAT_ID" ]; then
        read -p "请输入 GROUP_CHAT_ID [当前: $GROUP_CHAT_ID]: " new_group
    else
        read -p "请输入 GROUP_CHAT_ID: " new_group
    fi
    
    # 使用新值或保持原值
    new_token=${new_token:-$BOT_TOKEN}
    new_admin=${new_admin:-$ADMIN_USER_ID}
    new_group=${new_group:-$GROUP_CHAT_ID}
    
    # 验证输入
    if [ -z "$new_token" ] || [ -z "$new_admin" ] || [ -z "$new_group" ]; then
        echo -e "${RED}❌ 所有字段都必须填写！${NC}"
        sleep 2
        return
    fi
    
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
        # 安全地显示配置，隐藏敏感信息
        echo "BOT_TOKEN = ***（已设置）***"
        grep -v "BOT_TOKEN" "$CONFIG_FILE" | grep -v "DATABASE_NAME"
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
        if [ ! -f "$CONFIG_FILE" ]; then
            echo -e "${RED}❌ 配置未完成，安装取消${NC}"
            sleep 2
            return
        fi
    fi
    
    read_config
    
    echo -e "${YELLOW}即将使用以下配置安装:${NC}"
    echo -e "BOT_TOKEN: ***（已设置）***"
    echo -e "ADMIN_USER_ID: $ADMIN_USER_ID"
    echo -e "GROUP_CHAT_ID: $GROUP_CHAT_ID"
    echo ""
    
    read -p "确认安装？(y/n): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo -e "${YELLOW}安装取消${NC}"
        sleep 2
        return
    fi
    
    # 安装依赖
    echo -e "${BLUE}📦 安装系统依赖...${NC}"
    apt update && apt install -y python3 python3-pip python3-venv git
    
    # 创建项目目录
    echo -e "${BLUE}📁 创建项目目录...${NC}"
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # 创建虚拟环境
    echo -e "${BLUE}🐍 创建Python虚拟环境...${NC}"
    python3 -m venv bot-env
    
    # 安装Python包
    echo -e "${BLUE}📦 安装Python依赖...${NC}"
    source bot-env/bin/activate
    pip install python-telegram-bot
    deactivate
    
    # 创建主程序文件
    echo -e "${BLUE}💻 创建主程序文件...${NC}"
    cat > telegram_bot.py << 'EOL'
import logging
import sqlite3
from datetime import datetime
from telegram import Update
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes

# 导入配置
from bot_config import BOT_TOKEN, ADMIN_USER_ID, GROUP_CHAT_ID, DATABASE_NAME

# 设置日志
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

# 初始化数据库
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
    logger.info("数据库初始化完成")

# 记录用户使用情况
def record_user_usage(user_id, username, first_name, last_name):
    conn = sqlite3.connect(DATABASE_NAME)
    cursor = conn.cursor()
    now = datetime.now()
    
    cursor.execute("SELECT usage_count FROM user_usage WHERE user_id = ?", (user_id,))
    user = cursor.fetchone()
    
    if user:
        cursor.execute('''
            UPDATE user_usage 
            SET usage_count = usage_count + 1, 
                last_used = ?,
                username = ?,
                first_name = ?,
                last_name = ?
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

# 获取使用统计
def get_usage_stats():
    conn = sqlite3.connect(DATABASE_NAME)
    cursor = conn.cursor()
    
    cursor.execute("SELECT COUNT(*) FROM user_usage")
    total_users = cursor.fetchone()[0]
    
    cursor.execute("SELECT SUM(usage_count) FROM user_usage")
    total_messages = cursor.fetchone()[0] or 0
    
    cursor.execute("""
        SELECT user_id, username, first_name, last_name, usage_count, last_used 
        FROM user_usage 
        ORDER BY usage_count DESC 
        LIMIT 10
    """)
    top_users = cursor.fetchall()
    
    conn.close()
    return total_users, total_messages, top_users

# 处理/start命令
async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    await update.message.reply_text(
        f"你好 {user.first_name}！\n\n"
        "欢迎使用消息转发机器人。只需发送任何消息，我会将其转发到指定群组。"
    )

# 处理用户消息
async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    message = update.message
    
    # 记录用户使用情况
    record_user_usage(user.id, user.username, user.first_name, user.last_name)
    
    # 准备转发消息的文本
    forward_text = (
        f"来自用户: {user.first_name}"
        f"{' @' + user.username if user.username else ''}\n"
        f"用户ID: {user.id}\n\n"
        f"消息内容:\n{message.text}"
    )
    
    try:
        # 转发消息到群组
        await context.bot.send_message(
            chat_id=GROUP_CHAT_ID,
            text=forward_text
        )
        
        # 发送确认消息给用户
        await message.reply_text("您的消息已成功转发！")
        
        # 向管理员发送使用通知
        total_users, total_messages, top_users = get_usage_stats()
        
        stats_message = (
            f"📊 机器人使用统计:\n"
            f"总用户数: {total_users}\n"
            f"总消息数: $total_messages\n\n"
            f"最新用户: {user.first_name} (@{user.username})\n"
            f"用户ID: {user.id}"
        )
        
        await context.bot.send_message(
            chat_id=ADMIN_USER_ID,
            text=stats_message
        )
        
    except Exception as e:
        logger.error(f"发送消息时出错: {e}")
        await message.reply_text("抱歉，发送消息时出现错误。请检查机器人是否已添加到群组并有发送权限。")

# 处理/stats命令（仅管理员可用）
async def stats_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    
    if user.id != ADMIN_USER_ID:
        await update.message.reply_text("抱歉，您没有权限执行此命令。")
        return
    
    total_users, total_messages, top_users = get_usage_stats()
    
    stats_text = (
        f"🤖 机器人统计信息:\n\n"
        f"总用户数: {total_users}\n"
        f"总消息数: $total_messages\n\n"
        f"📈 使用最多的前10位用户:\n"
    )
    
    for i, (user_id, username, first_name, last_name, usage_count, last_used) in enumerate(top_users, 1):
        display_name = f"{first_name or ''} {last_name or ''}".strip()
        if username:
            display_name += f" (@{username})"
        stats_text += f"{i}. {display_name}: {usage_count} 次\n"
    
    await update.message.reply_text(stats_text)

# 错误处理
async def error_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    logger.error(f"更新 {update} 导致错误: {context.error}")
    
    # 向管理员发送错误报告
    try:
        error_message = f"⚠️ 机器人错误:\n{context.error}"
        await context.bot.send_message(chat_id=ADMIN_USER_ID, text=error_message)
    except:
        pass

# 主函数
def main():
    # 初始化数据库
    init_database()
    
    # 创建应用
    application = Application.builder().token(BOT_TOKEN).build()
    
    # 添加处理器
    application.add_handler(CommandHandler("start", start_command))
    application.add_handler(CommandHandler("stats", stats_command))
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
    
    # 添加错误处理
    application.add_error_handler(error_handler)
    
    # 启动机器人
    logger.info("🤖 机器人启动中...")
    print("🤖 机器人已启动！按 Ctrl+C 停止")
    application.run_polling()

if __name__ == "__main__":
    main()
EOL

    # 创建启动脚本
    echo -e "${BLUE}📜 创建启动脚本...${NC}"
    cat > start_bot.sh << 'EOL'
#!/bin/bash
cd /root/telegram-bot
source /root/telegram-bot/bot-env/bin/activate
python /root/telegram-bot/telegram_bot.py
EOL

    chmod +x start_bot.sh

    # 创建systemd服务
    echo -e "${BLUE}🔧 创建系统服务...${NC}"
    cat > /tmp/telegram-bot.service << EOL
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
EOL

    sudo mv /tmp/telegram-bot.service "$SERVICE_FILE"
    sudo systemctl daemon-reload
    sudo systemctl enable telegram-bot

    echo -e "${GREEN}✅ 安装完成！${NC}"
    echo -e "${YELLOW}📋 使用命令启动: systemctl start telegram-bot${NC}"
    sleep 3
}

# 启动服务
start_bot() {
    clear
    echo -e "${BLUE}=== 启动机器人 ===${NC}"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}❌ 请先安装和配置机器人!${NC}"
        sleep 2
        return
    fi
    
    sudo systemctl start telegram-bot
    sleep 2
    
    if systemctl is-active --quiet telegram-bot; then
        echo -e "${GREEN}✅ 机器人启动成功!${NC}"
    else
        echo -e "${RED}❌ 机器人启动失败!${NC}"
        echo -e "${YELLOW}查看日志: journalctl -u telegram-bot -n 20${NC}"
    fi
    
    sleep 2
}

# 停止服务
stop_bot() {
    clear
    echo -e "${BLUE}=== 停止机器人 ===${NC}"
    
    sudo systemctl stop telegram-bot
    sleep 2
    
    if systemctl is-active --quiet telegram-bot; then
        echo -e "${RED}❌ 停止失败!${NC}"
    else
        echo -e "${GREEN}✅ 机器人已停止!${NC}"
    fi
    
    sleep 2
}

# 重启服务
restart_bot() {
    clear
    echo -e "${BLUE}=== 重启机器人 ===${NC}"
    
    sudo systemctl restart telegram-bot
    sleep 2
    
    if systemctl is-active --quiet telegram-bot; then
        echo -e "${GREEN}✅ 重启成功!${NC}"
    else
        echo -e "${RED}❌ 重启失败!${NC}"
    fi
    
    sleep 2
}

# 查看状态
status_bot() {
    clear
    echo -e "${BLUE}=== 机器人状态 ===${NC}"
    
    sudo systemctl status telegram-bot --no-pager -l
    
    echo ""
    read -p "按回车键返回菜单..."
}

# 卸载机器人
uninstall_bot() {
    clear
    echo -e "${RED}=== 卸载机器人 ===${NC}"
    
    read -p "确定要卸载机器人吗？(y/n): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo -e "${YELLOW}卸载取消${NC}"
        sleep 2
        return
    fi
    
    echo -e "${BLUE}🛑 停止服务...${NC}"
    sudo systemctl stop telegram-bot 2>/dev/null
    sudo systemctl disable telegram-bot 2>/dev/null
    
    echo -e "${BLUE}🗑️ 删除服务文件...${NC}"
    sudo rm -f "$SERVICE_FILE"
    sudo systemctl daemon-reload
    
    echo -e "${BLUE}🔍 清理进程...${NC}"
    pkill -f "telegram_bot.py" 2>/dev/null || true
    pkill -f "start_bot.sh" 2>/dev/null || true
    
    read -p "是否删除项目目录和配置？(y/n): " delete_files
    if [ "$delete_files" = "y" ] || [ "$delete_files" = "Y" ]; then
        echo -e "${BLUE}🗑️ 删除项目文件...${NC}"
        rm -rf "$INSTALL_DIR"
    else
        echo -e "${YELLOW}⚠️ 保留项目文件: $INSTALL_DIR${NC}"
    fi
    
    echo -e "${GREEN}✅ 卸载完成!${NC}"
    sleep 2
}

# 生成安装脚本
generate_script() {
    clear
    echo -e "${BLUE}=== 生成安装脚本 ===${NC}"
    
    SCRIPT_FILE="/tmp/install_telegram_bot.sh"
    
    cat > "$SCRIPT_FILE" << 'EOL'
#!/bin/bash

# Telegram 机器人自动安装脚本
# 需要手动配置敏感信息

echo "🚀 开始安装 Telegram 消息转发机器人..."

# 安装依赖
echo "📦 安装系统依赖..."
apt update && apt install -y python3 python3-pip python3-venv git

# 创建项目目录
echo "📁 创建项目目录..."
mkdir -p /root/telegram-bot
cd /root/telegram-bot

# 创建虚拟环境
echo "🐍 创建Python虚拟环境..."
python3 -m venv bot-env
source bot-env/bin/activate

# 安装Python包
echo "📦 安装Python依赖..."
pip install python-telegram-bot
deactivate

# 创建配置文件
echo "⚙️ 创建配置文件..."
cat > bot_config.py << 'EOF'
# 机器人配置
BOT_TOKEN = "请在此处填写您的BOT_TOKEN"
ADMIN_USER_ID = 请在此处填写您的用户ID
GROUP_CHAT_ID = 请在此处填写群组ID
DATABASE_NAME = "bot_usage.db"
EOF

echo "⚠️ 请编辑 /root/telegram-bot/bot_config.py 文件填写正确的配置"

# 创建主程序文件
echo "💻 创建主程序文件..."
cat > telegram_bot.py << 'EOF'
import logging
import sqlite3
from datetime import datetime
from telegram import Update
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes

# 导入配置
from bot_config import BOT_TOKEN, ADMIN_USER_ID, GROUP_CHAT_ID, DATABASE_NAME

# 设置日志
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

# 初始化数据库
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
    logger.info("数据库初始化完成")

# 记录用户使用情况
def record_user_usage(user_id, username, first_name, last_name):
    conn = sqlite3.connect(DATABASE_NAME)
    cursor = conn.cursor()
    now = datetime.now()
    
    cursor.execute("SELECT usage_count FROM user_usage WHERE user_id = ?", (user_id,))
    user = cursor.fetchone()
    
    if user:
        cursor.execute('''
            UPDATE user_usage 
            SET usage_count = usage_count + 1, 
                last_used = ?,
                username = ?,
                first_name = ?,
                last_name = ?
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

# 获取使用统计
def get_usage_stats():
    conn = sqlite3.connect(DATABASE_NAME)
    cursor = conn.cursor()
    
    cursor.execute("SELECT COUNT(*) FROM user_usage")
    total_users = cursor.fetchone()[0]
    
    cursor.execute("SELECT SUM(usage_count) FROM user_usage")
    total_messages = cursor.fetchone()[0] or 0
    
    cursor.execute("""
        SELECT user_id, username, first_name, last_name, usage_count, last_used 
        FROM user_usage 
        ORDER BY usage_count DESC 
        LIMIT 10
    """)
    top_users = cursor.fetchall()
    
    conn.close()
    return total_users, total_messages, top_users

# 处理/start命令
async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    await update.message.reply_text(
        f"你好 {user.first_name}！\n\n"
        "欢迎使用消息转发机器人。只需发送任何消息，我会将其转发到指定群组。"
    )

# 处理用户消息
async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    message = update.message
    
    # 记录用户使用情况
    record_user_usage(user.id, user.username, user.first_name, user.last_name)
    
    # 准备转发消息的文本
    forward_text = (
        f"来自用户: {user.first_name}"
        f"{' @' + user.username if user.username else ''}\n"
        f"用户ID: {user.id}\n\n"
        f"消息内容:\n{message.text}"
    )
    
    try:
        # 转发消息到群组
        await context.bot.send_message(
            chat_id=GROUP_CHAT_ID,
            text=forward_text
        )
        
        # 发送确认消息给用户
        await message.reply_text("您的消息已成功转发！")
        
        # 向管理员发送使用通知
        total_users, total_messages, top_users = get_usage_stats()
        
        stats_message = (
            f"📊 机器人使用统计:\n"
            f"总用户数: {total_users}\n"
            f"总消息数: $total_messages\n\n"
            f"最新用户: {user.first_name} (@{user.username})\n"
            f"用户ID: {user.id}"
        )
        
        await context.bot.send_message(
            chat_id=ADMIN_USER_ID,
            text=stats_message
        )
        
    except Exception as e:
        logger.error(f"发送消息时出错: {e}")
        await message.reply_text("抱歉，发送消息时出现错误。请检查机器人是否已添加到群组并有发送权限。")

# 处理/stats命令（仅管理员可用）
async def stats_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    
    if user.id != ADMIN_USER_ID:
        await update.message.reply_text("抱歉，您没有权限执行此命令。")
        return
    
    total_users, total_messages, top_users = get_usage_stats()
    
    stats_text = (
        f"🤖 机器人统计信息:\n\n"
        f"总用户数: {total_users}\n"
        f"总消息数: $total_messages\n\n"
        f"📈 使用最多的前10位用户:\n"
    )
    
    for i, (user_id, username, first_name, last_name, usage_count, last_used) in enumerate(top_users, 1):
        display_name = f"{first_name or ''} {last_name or ''}".strip()
        if username:
            display_name += f" (@{username})"
        stats_text += f"{i}. {display_name}: {usage_count} 次\n"
    
    await update.message.reply_text(stats_text)

# 错误处理
async def error_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    logger.error(f"更新 {update} 导致错误: {context.error}")
    
    # 向管理员发送错误报告
    try:
        error_message = f"⚠️ 机器人错误:\n{context.error}"
        await context.bot.send_message(chat_id=ADMIN_USER_ID, text=error_message)
    except:
        pass

# 主函数
def main():
    # 初始化数据库
    init_database()
    
    # 创建应用
    application = Application.builder().token(BOT_TOKEN).build()
    
    # 添加处理器
    application.add_handler(CommandHandler("start", start_command))
    application.add_handler(CommandHandler("stats", stats_command))
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
    
    # 添加错误处理
    application.add_error_handler(error_handler)
    
    # 启动机器人
    logger.info("🤖 机器人启动中...")
    print("🤖 机器人已启动！按 Ctrl+C 停止")
    application.run_polling()

if __name__ == "__main__":
    main()
EOF

# 创建启动脚本
echo "📜 创建启动脚本..."
cat > start_bot.sh << 'EOF'
#!/bin/bash
cd /root/telegram-bot
source /root/telegram-bot/bot-env/bin/activate
python /root/telegram-bot/telegram_bot.py
EOF

chmod +x start_bot.sh

# 创建systemd服务
echo "🔧 创建系统服务..."
cat > /etc/systemd/system/telegram-bot.service << EOF
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

# 启用服务
systemctl daemon-reload
systemctl enable telegram-bot

echo "✅ 安装完成！"
echo "📋 请完成以下步骤："
echo "1. 编辑 /root/telegram-bot/bot_config.py 填写正确配置"
echo "2. 启动服务: systemctl start telegram-bot"
echo "3. 查看状态: systemctl status telegram-bot"
EOL

    chmod +x "$SCRIPT_FILE"
    
    echo -e "${GREEN}✅ 安装脚本已生成: $SCRIPT_FILE${NC}"
    echo -e "${YELLOW}📋 生成的脚本不包含敏感信息，需要手动编辑配置文件${NC}"
    sleep 3
}

# 主循环
while true; do
    show_menu
    
    case $choice in
        1) install_bot ;;
        2) configure_bot ;;
        3) view_config ;;
        4) start_bot ;;
        5) stop_bot ;;
        6) restart_bot ;;
        7) status_bot ;;
        8) uninstall_bot ;;
        9) generate_script ;;
        0)
            echo -e "${GREEN}再见！${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}无效选择，请重新输入${NC}"
            sleep 2
            ;;
    esac
done
```
