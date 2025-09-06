#!/bin/bash

# Telegram 机器人转发消息脚本 
CONFIG_FILE="/root/telegram-bot/bot_config.py"
INSTALL_DIR="/root/telegram-bot"
SERVICE_FILE="/etc/systemd/system/telegram-bot.service"
SCRIPT_FILE="/root/bot_manager.sh"

# 自动设置执行权限
if [ ! -x "$SCRIPT_FILE" ]; then
    chmod +x "$SCRIPT_FILE"
    echo "已自动设置执行权限"
fi

# 颜色设置
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 显示菜单
show_menu() {
    clear
    echo "================================================"
    echo "           Telegram 机器人管理脚本            "
    echo "================================================"
    echo "1. 安装机器人"
    echo "2. 配置机器人参数"
    echo "3. 查看当前配置"
    echo "4. 启动机器人"
    echo "5. 停止机器人"
    echo "6. 重启机器人"
    echo "7. 查看运行状态"
    echo "8. 卸载机器人"
    echo "9. 生成安装脚本"
    echo "10. 卸载管理脚本"
    echo "0. 退出脚本"
    echo "================================================"
    
    read -p "请输入您的选择 [0-10]: " choice
}

# 读取配置
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
    echo "=== 配置机器人参数 ==="
    
    read_config
    
    echo "请输入机器人配置信息："
    echo ""
    
    read -p "请输入 BOT_TOKEN: " new_token
    read -p "请输入 ADMIN_USER_ID: " new_admin
    read -p "请输入 GROUP_CHAT_ID: " new_group
    
    if [ -z "$new_token" ] || [ -z "$new_admin" ] || [ -z "$new_group" ]; then
        echo "错误：所有字段都必须填写！"
        sleep 2
        return 1
    fi
    
    mkdir -p "$INSTALL_DIR"
    
    cat > "$CONFIG_FILE" << EOL
# 机器人配置
BOT_TOKEN = "$new_token"
ADMIN_USER_ID = $new_admin
GROUP_CHAT_ID = $new_group
DATABASE_NAME = "bot_usage.db"
EOL
    
    echo "配置已保存!"
    sleep 2
}

# 查看配置
view_config() {
    clear
    echo "=== 当前配置 ==="
    
    if [ -f "$CONFIG_FILE" ]; then
        echo "配置文件: $CONFIG_FILE"
        echo ""
        echo "BOT_TOKEN = ***（已设置）***"
        grep -v "BOT_TOKEN" "$CONFIG_FILE" | grep -v "DATABASE_NAME"
    else
        echo "配置文件不存在"
    fi
    
    echo ""
    echo "=== 服务状态 ==="
    if systemctl is-active --quiet telegram-bot; then
        echo "机器人正在运行"
    else
        echo "机器人未运行"
    fi
    
    echo ""
    read -p "按回车键返回菜单..."
}

# 安装机器人
install_bot() {
    clear
    echo "=== 安装 Telegram 机器人 ==="
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "请先配置机器人参数!"
        sleep 2
        configure_bot
        if [ ! -f "$CONFIG_FILE" ]; then
            echo "配置未完成，安装取消"
            sleep 2
            return 1
        fi
    fi
    
    read_config
    
    echo "即将使用以下配置安装:"
    echo "BOT_TOKEN: ***"
    echo "ADMIN_USER_ID: $ADMIN_USER_ID"
    echo "GROUP_CHAT_ID: $GROUP_CHAT_ID"
    echo ""
    
    read -p "确认安装？(y/n): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "安装取消"
        sleep 2
        return 1
    fi
    
    echo "安装系统依赖..."
    apt update && apt install -y python3 python3-pip python3-venv git
    
    echo "创建项目目录..."
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    echo "创建Python虚拟环境..."
    python3 -m venv bot-env
    
    echo "安装Python依赖..."
    source bot-env/bin/activate
    pip install python-telegram-bot
    deactivate
    
    echo "创建主程序文件..."
    cat > telegram_bot.py << 'EOL'
import logging
import sqlite3
from datetime import datetime
from telegram import Update
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes
from telegram.constants import ParseMode

from bot_config import BOT_TOKEN, ADMIN_USER_ID, GROUP_CHAT_ID, DATABASE_NAME

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

async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    await update.message.reply_text(
        f"你好 {user.first_name}！\n\n"
        "欢迎使用消息转发机器人！\n"
        "您可以发送：\n"
        "• 文本消息\n"
        "• 图片/照片\n"
        "• 视频\n"
        "• 文件/文档\n"
        "• 语音消息\n"
        "• 贴纸\n\n"
        "所有内容都会转发到指定群组。"
        "此服务由 @Lxi0707 脚本搭建"
    )

async def handle_private_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """只处理私聊消息，忽略群组消息"""
    if update.message.chat.type != "private":
        return
    
    user = update.effective_user
    message = update.message
    
    # 记录用户使用情况
    record_user_usage(user.id, user.username, user.first_name, user.last_name)
    
    # 准备转发消息的文本
    user_info = f"来自用户: {user.first_name}"
    if user.username:
        user_info += f" (@{user.username})"
    user_info += f"\n用户ID: {user.id}"
    
    try:
        # 转发不同类型的消息
        if message.text:
            # 文本消息
            forward_text = f"{user_info}\n\n消息内容:\n{message.text}"
            await context.bot.send_message(
                chat_id=GROUP_CHAT_ID,
                text=forward_text,
                parse_mode=ParseMode.HTML
            )
            
        elif message.photo:
            # 图片消息
            caption = f"{user_info}\n\n图片消息"
            if message.caption:
                caption += f"\n描述: {message.caption}"
            
            # 获取最高质量的图片
            photo_file = await message.photo[-1].get_file()
            await context.bot.send_photo(
                chat_id=GROUP_CHAT_ID,
                photo=photo_file.file_id,
                caption=caption
            )
            
        elif message.video:
            # 视频消息 - 修复转发问题
            caption = f"{user_info}\n\n视频消息"
            if message.caption:
                caption += f"\n描述: {message.caption}"
            
            # 直接使用视频文件ID，避免下载和重新上传
            await context.bot.send_video(
                chat_id=GROUP_CHAT_ID,
                video=message.video.file_id,
                caption=caption
            )
            
        elif message.document:
            # 文件/文档
            caption = f"{user_info}\n\n文件: {message.document.file_name}"
            if message.caption:
                caption += f"\n描述: {message.caption}"
            
            # 直接使用文档文件ID
            await context.bot.send_document(
                chat_id=GROUP_CHAT_ID,
                document=message.document.file_id,
                caption=caption
            )
            
        elif message.voice:
            # 语音消息
            caption = f"{user_info}\n\n语音消息"
            # 直接使用语音文件ID
            await context.bot.send_voice(
                chat_id=GROUP_CHAT_ID,
                voice=message.voice.file_id,
                caption=caption
            )
            
        elif message.sticker:
            # 贴纸 - 修复转发问题
            caption = f"{user_info}\n\n发送了贴纸"
            # 直接使用贴纸文件ID
            await context.bot.send_sticker(
                chat_id=GROUP_CHAT_ID,
                sticker=message.sticker.file_id
            )
            # 贴纸不能有caption，所以单独发送说明文字
            await context.bot.send_message(
                chat_id=GROUP_CHAT_ID,
                text=caption
            )
            
        elif message.audio:
            # 音频文件
            caption = f"{user_info}\n\n音频文件"
            if message.caption:
                caption += f"\n描述: {message.caption}"
            
            # 直接使用音频文件ID
            await context.bot.send_audio(
                chat_id=GROUP_CHAT_ID,
                audio=message.audio.file_id,
                caption=caption
            )
        
        # 发送确认消息给用户
        await message.reply_text("✅ 您的消息已成功转发到群组！")
        
    except Exception as e:
        logger.error(f"发送消息时出错: {e}")
        error_msg = "❌ 发送失败"
        if "file is too big" in str(e):
            error_msg += "（文件过大）"
        elif "not found" in str(e):
            error_msg += "（文件访问受限）"
        elif "forward" in str(e):
            error_msg += "（转发限制）"
        await message.reply_text(error_msg)

async def stats_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """统计命令 - 仅管理员可用"""
    user = update.effective_user
    
    if user.id != ADMIN_USER_ID:
        await update.message.reply_text("❌ 抱歉，您没有权限执行此命令。")
        return
    
    # 获取统计信息
    conn = sqlite3.connect(DATABASE_NAME)
    cursor = conn.cursor()
    
    cursor.execute("SELECT COUNT(*) FROM user_usage")
    total_users = cursor.fetchone()[0]
    
    cursor.execute("SELECT SUM(usage_count) FROM user_usage")
    total_messages = cursor.fetchone()[0] or 0
    
    cursor.execute("SELECT username, first_name, last_name, usage_count FROM user_usage ORDER BY usage_count DESC LIMIT 5")
    top_users = cursor.fetchall()
    
    conn.close()
    
    # 构建统计消息
    stats_text = f"🤖 <b>机器人统计信息</b>\n\n"
    stats_text += f"👥 总用户数: <code>{total_users}</code>\n"
    stats_text += f"📨 总消息数: <code>{total_messages}</code>\n\n"
    stats_text += f"🏆 <b>Top 5 活跃用户:</b>\n"
    
    for i, (username, first_name, last_name, usage_count) in enumerate(top_users, 1):
        display_name = f"{first_name or ''} {last_name or ''}".strip()
        if username:
            display_name += f" (@{username})"
        stats_text += f"{i}. {display_name}: {usage_count} 次\n"
    
    await update.message.reply_text(stats_text, parse_mode=ParseMode.HTML)

async def error_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """错误处理"""
    logger.error(f"机器人错误: {context.error}")
    
    # 向管理员发送错误报告
    try:
        error_message = f"⚠️ 机器人错误:\n{context.error}"
        await context.bot.send_message(chat_id=ADMIN_USER_ID, text=error_message)
    except Exception as e:
        logger.error(f"发送错误报告失败: {e}")

def main():
    # 初始化数据库
    init_database()
    
    # 创建应用
    application = Application.builder().token(BOT_TOKEN).build()
    
    # 添加处理器 - 只处理私聊消息
    application.add_handler(CommandHandler("start", start_command))
    application.add_handler(CommandHandler("stats", stats_command))
    
    # 处理所有类型的私聊消息，忽略群组消息
    application.add_handler(MessageHandler(
        filters.ChatType.PRIVATE & (
            filters.TEXT | filters.PHOTO | filters.VIDEO | 
            filters.Document.ALL | filters.VOICE | filters.Sticker.ALL |
            filters.AUDIO
        ),
        handle_private_message
    ))
    
    # 添加错误处理
    application.add_error_handler(error_handler)
    
    # 启动机器人
    logger.info("🤖 机器人启动中...")
    print("🤖 机器人已启动！按 Ctrl+C 停止")
    application.run_polling()

if __name__ == "__main__":
    main()
EOL

    echo "创建启动脚本..."
    cat > start_bot.sh << 'EOL'
#!/bin/bash
cd /root/telegram-bot
source /root/telegram-bot/bot-env/bin/activate
python /root/telegram-bot/telegram_bot.py
EOL

    chmod +x start_bot.sh

    echo "创建系统服务..."
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

    mv /tmp/telegram-bot.service "$SERVICE_FILE"
    systemctl daemon-reload
    systemctl enable telegram-bot

    echo "安装完成！"
    echo "使用命令启动: systemctl start telegram-bot"
    sleep 3
}

# 启动服务
start_service() {
    clear
    echo "=== 启动机器人 ==="
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "请先安装和配置机器人!"
        sleep 2
        return 1
    fi
    
    systemctl start telegram-bot
    sleep 2
    
    if systemctl is-active --quiet telegram-bot; then
        echo "机器人启动成功!"
    else
        echo "机器人启动失败!"
        echo "查看日志: journalctl -u telegram-bot -n 20"
    fi
    
    sleep 2
}

# 停止服务
stop_service() {
    clear
    echo "=== 停止机器人 ==="
    
    systemctl stop telegram-bot
    sleep 2
    
    if systemctl is-active --quiet telegram-bot; then
        echo "停止失败!"
    else
        echo "机器人已停止!"
    fi
    
    sleep 2
}

# 重启服务
restart_service() {
    clear
    echo "=== 重启机器人 ==="
    
    systemctl restart telegram-bot
    sleep 2
    
    if systemctl is-active --quiet telegram-bot; then
        echo "重启成功!"
    else
        echo "重启失败!"
    fi
    
    sleep 2
}

# 查看状态
view_status() {
    clear
    echo "=== 机器人状态 ==="
    
    systemctl status telegram-bot --no-pager -l
    
    echo ""
    read -p "按回车键返回菜单..."
}

# 卸载机器人
uninstall_bot() {
    clear
    echo "=== 卸载机器人 ==="
    
    read -p "确定要卸载机器人吗？(y/n): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "卸载取消"
        sleep 2
        return 1
    fi
    
    echo "停止服务..."
    systemctl stop telegram-bot 2>/dev/null
    systemctl disable telegram-bot 2>/dev/null
    
    echo "删除服务文件..."
    rm -f "$SERVICE_FILE"
    systemctl daemon-reload
    
    echo "清理进程..."
    pkill -f "telegram_bot.py" 2>/dev/null || true
    pkill -f "start_bot.sh" 2>/dev/null || true
    
    read -p "是否删除项目目录和配置？(y/n): " delete_files
    if [ "$delete_files" = "y" ] || [ "$delete_files" = "Y" ]; then
        echo "删除项目文件..."
        rm -rf "$INSTALL_DIR"
        echo "项目目录已删除"
    else
        echo "保留项目目录: $INSTALL_DIR"
    fi
    
    echo "卸载完成!"
    sleep 2
}

# 生成安装脚本
generate_script() {
    clear
    echo "=== 生成安装脚本 ==="
    echo "此功能待实现"
    sleep 2
}

# 卸载管理脚本
uninstall_manager() {
    clear
    echo "=== 卸载管理脚本 ==="
    echo ""
    echo "这将删除管理脚本本身，但不会影响已安装的机器人。"
    echo ""
    
    read -p "确定要卸载管理脚本吗？(y/n): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "卸载取消"
        sleep 2
        return 1
    fi
    
    # 删除alias
    if [ -f ~/.bashrc ]; then
        sed -i '/alias botm=/d' ~/.bashrc
        echo "已删除alias配置"
    fi
    
    # 删除脚本文件
    if [ -f "$SCRIPT_FILE" ]; then
        rm -f "$SCRIPT_FILE"
        echo "已删除管理脚本: $SCRIPT_FILE"
    fi
    
    echo ""
    echo "管理脚本已卸载完成！"
    echo "注意：机器人服务仍然存在，如需卸载机器人请先使用选项8"
    sleep 3
    
    # 退出脚本
    exit 0
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
            10) uninstall_manager ;;
            0)
                echo "再见！"
                exit 0
                ;;
            *)
                echo "无效选择，请重新输入"
                sleep 2
                ;;
        esac
    done
}

# 检查是否以root运行
if [ "$EUID" -ne 0 ]; then 
    echo "请使用root权限运行此脚本"
    exit 1
fi

# 启动主程序
main
