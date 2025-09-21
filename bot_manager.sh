#!/bin/bash


# Telegram 机器人转发消息脚本 


# 用户使用bot，发送任意内容，bot识别后均可识别转发到指定的群组(可以添加绑定群组变量，添加后用户必须关注频道 ID/用户名 才可使用）
# 参数介绍
# BOT_TOKEN 从 @BotFather 获取 123456:ABC-DEF...
# ADMIN_USER_ID 管理员用户ID 123456789
# GROUP_CHAT_ID 接收消息的群组ID -1001234567890
# REQUIRED_CHANNELS 用户必须加入的频道（可选） @channel1,-100123456789
# 多个频道用英文逗号分隔，支持 @用户名 和 -100 开头的ID格式。



CONFIG_FILE="/root/telegram-bot/bot_config.py"
INSTALL_DIR="/root/telegram-bot"
SERVICE_FILE="/etc/systemd/system/telegram-bot.service"
SCRIPT_FILE="/root/bot_manager.sh"

if [ ! -x "$SCRIPT_FILE" ]; then
    chmod +x "$SCRIPT_FILE"
    echo "已自动设置执行权限"
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

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
    echo "8. 查看日志"
    echo "9. 卸载机器人"
    echo "10. 卸载管理脚本"
    echo "0. 退出脚本"
    echo "================================================"
    
    read -p "请输入您的选择 [0-10]: " choice
}

read_config() {
    if [ -f "$CONFIG_FILE" ]; then
        BOT_TOKEN=$(grep "BOT_TOKEN" "$CONFIG_FILE" | awk -F'"' '{print $2}')
        ADMIN_USER_ID=$(grep "ADMIN_USER_ID" "$CONFIG_FILE" | awk '{print $3}')
        GROUP_CHAT_ID=$(grep "GROUP_CHAT_ID" "$CONFIG_FILE" | awk '{print $3}')
        
        if grep -q "REQUIRED_CHANNELS" "$CONFIG_FILE"; then
            REQUIRED_CHANNELS=$(grep "REQUIRED_CHANNELS" "$CONFIG_FILE" | sed 's/.*= \[\([^]]*\)\].*/\1/' | sed "s/'//g; s/ //g")
        else
            REQUIRED_CHANNELS=""
        fi
    else
        BOT_TOKEN=""
        ADMIN_USER_ID=""
        GROUP_CHAT_ID=""
        REQUIRED_CHANNELS=""
    fi
}

configure_bot() {
    local current_bot_token=""
    local current_admin_id=""
    local current_group_id=""
    local current_channels=""
    
    if [ -f "$CONFIG_FILE" ]; then
        current_bot_token=$(grep "BOT_TOKEN" "$CONFIG_FILE" | awk -F'"' '{print $2}')
        current_admin_id=$(grep "ADMIN_USER_ID" "$CONFIG_FILE" | awk '{print $3}')
        current_group_id=$(grep "GROUP_CHAT_ID" "$CONFIG_FILE" | awk '{print $3}')
        
        if grep -q "REQUIRED_CHANNELS" "$CONFIG_FILE"; then
            current_channels=$(grep "REQUIRED_CHANNELS" "$CONFIG_FILE" | sed 's/.*= \[\([^]]*\)\].*/\1/' | sed "s/'//g; s/ //g")
        fi
    fi
    
    local bot_token="$current_bot_token"
    local admin_id="$current_admin_id"
    local group_id="$current_group_id"
    local channels="$current_channels"
    
    while true; do
        clear
        echo "=== 配置机器人参数 ==="
        
        echo "当前配置:"
        echo "1. BOT_TOKEN: ${bot_token:+***（已设置）***}"
        echo "2. ADMIN_USER_ID: ${admin_id:-未设置}"
        echo "3. GROUP_CHAT_ID: ${group_id:-未设置}"
        echo "4. 需要加入的频道/群组: ${channels:-未设置}"
        echo ""
        echo "请选择要配置的选项："
        echo "1. 配置 BOT_TOKEN"
        echo "2. 配置 ADMIN_USER_ID"
        echo "3. 配置 GROUP_CHAT_ID"
        echo "4. 配置需要加入的频道/群组"
        echo "5. 配置所有参数"
        echo "6. 保存并返回主菜单"
        echo "0. 返回主菜单（不保存）"
        echo ""
        
        read -p "请输入您的选择 [0-6]: " config_choice
        
        case $config_choice in
            1)
                read -p "请输入 BOT_TOKEN: " new_token
                if [ -n "$new_token" ]; then
                    bot_token="$new_token"
                    echo "BOT_TOKEN 已更新"
                else
                    echo "输入为空，保持原值"
                fi
                sleep 1
                ;;
            2)
                read -p "请输入 ADMIN_USER_ID: " new_admin
                if [ -n "$new_admin" ]; then
                    admin_id="$new_admin"
                    echo "ADMIN_USER_ID 已更新"
                else
                    echo "输入为空，保持原值"
                fi
                sleep 1
                ;;
            3)
                read -p "请输入 GROUP_CHAT_ID: " new_group
                if [ -n "$new_group" ]; then
                    group_id="$new_group"
                    echo "GROUP_CHAT_ID 已更新"
                else
                    echo "输入为空，保持原值"
                fi
                sleep 1
                ;;
            4)
                echo "请输入需要加入的频道/群组（多个用逗号分隔）"
                echo "格式说明："
                echo "- 公开频道/群组: @username (例如: @my_channel)"
                echo "- 私密群组: -100123456789 (使用数字ID)"
                echo "- 多个用逗号分隔: @channel1,-100123456789,@channel2"
                read -p "请输入: " new_channels
                if [ -n "$new_channels" ]; then
                    channels="$new_channels"
                    echo "频道列表已更新"
                else
                    echo "输入为空，保持原值"
                fi
                sleep 1
                ;;
            5)
                read -p "请输入 BOT_TOKEN: " new_token
                read -p "请输入 ADMIN_USER_ID: " new_admin
                read -p "请输入 GROUP_CHAT_ID: " new_group
                echo "请输入需要加入的频道/群组（多个用逗号分隔）"
                echo "格式：@username 或 -100123456789，多个用逗号分隔"
                read -p "请输入: " new_channels
                
                if [ -n "$new_token" ]; then
                    bot_token="$new_token"
                fi
                if [ -n "$new_admin" ]; then
                    admin_id="$new_admin"
                fi
                if [ -n "$new_group" ]; then
                    group_id="$new_group"
                fi
                if [ -n "$new_channels" ]; then
                    channels="$new_channels"
                fi
                
                echo "所有参数已更新"
                sleep 1
                ;;
            6)
                if [ -z "$bot_token" ]; then
                    echo "错误：BOT_TOKEN 必须填写！"
                    sleep 2
                    continue
                fi
                if [ -z "$admin_id" ]; then
                    echo "错误：ADMIN_USER_ID 必须填写！"
                    sleep 2
                    continue
                fi
                if [ -z "$group_id" ]; then
                    echo "错误：GROUP_CHAT_ID 必须填写！"
                    sleep 2
                    continue
                fi
                
                mkdir -p "$INSTALL_DIR"
                
                local formatted_channels="[]"
                if [ -n "$channels" ]; then
                    IFS=',' read -ra CHANNEL_ARRAY <<< "$channels"
                    formatted_channels="["
                    for i in "${!CHANNEL_ARRAY[@]}"; do
                        if [ $i -gt 0 ]; then
                            formatted_channels+=", "
                        fi
                        formatted_channels+="'${CHANNEL_ARRAY[$i]}'"
                    done
                    formatted_channels+="]"
                fi
                
                cat > "$CONFIG_FILE" << EOL
BOT_TOKEN = "$bot_token"
ADMIN_USER_ID = $admin_id
GROUP_CHAT_ID = $group_id
REQUIRED_CHANNELS = $formatted_channels
DATABASE_NAME = "bot_usage.db"
EOL
                
                echo "配置已保存到 $CONFIG_FILE"
                echo "BOT_TOKEN: ***"
                echo "ADMIN_USER_ID: $admin_id"
                echo "GROUP_CHAT_ID: $group_id"
                echo "REQUIRED_CHANNELS: ${channels:-无}"
                sleep 2
                return 0
                ;;
            0)
                read -p "确定要放弃更改并返回主菜单吗？(y/n): " confirm
                if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                    return 0
                fi
                ;;
            *)
                echo "无效选择"
                sleep 2
                ;;
        esac
    done
}

view_config() {
    clear
    echo "=== 当前配置 ==="
    
    if [ -f "$CONFIG_FILE" ]; then
        echo "配置文件: $CONFIG_FILE"
        echo ""
        echo "BOT_TOKEN = ***（已设置）***"
        grep -v "BOT_TOKEN" "$CONFIG_FILE" | grep -v "DATABASE_NAME" | while read line; do
            echo "$line"
        done
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
    echo "REQUIRED_CHANNELS: ${REQUIRED_CHANNELS:-无}"
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
    # 确保在虚拟环境中安装依赖
    source bot-env/bin/activate
    pip install --upgrade pip
    pip install python-telegram-bot httpx sqlite3
    deactivate
    
    # 验证依赖是否安装成功
    echo "验证依赖安装..."
    source bot-env/bin/activate
    if python -c "import telegram, httpx, sqlite3" &>/dev/null; then
        echo "依赖安装成功!"
    else
        echo "依赖安装失败，尝试重新安装..."
        pip install --force-reinstall python-telegram-bot httpx
    fi
    deactivate
    
    echo "创建主程序文件..."
    cat > "$INSTALL_DIR/telegram_bot.py" << 'EOL'
import logging
import sqlite3
import httpx
import asyncio
from datetime import datetime
from telegram import Update
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes
from telegram.constants import ParseMode

from bot_config import BOT_TOKEN, ADMIN_USER_ID, GROUP_CHAT_ID, REQUIRED_CHANNELS, DATABASE_NAME

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

async def is_member_of_channel(user_id, channel_identifier, bot_token):
    if not channel_identifier:
        return True
        
    try:
        async with httpx.AsyncClient() as client:
            url = f"https://api.telegram.org/bot{bot_token}/getChatMember"
            params = {
                "chat_id": channel_identifier,
                "user_id": user_id
            }
            response = await client.get(url, params=params)
            member_data = response.json()
            
            if member_data.get("ok"):
                status = member_data["result"]["status"]
                allowed_statuses = ["member", "administrator", "creator"]
                logger.info(f"用户 {user_id} 在频道 {channel_identifier} 的状态: {status}")
                return status in allowed_statuses
            else:
                logger.warning(f"无法获取成员状态: {member_data}")
                return False
                
    except Exception as e:
        logger.error(f"检查频道成员时出错: {e}")
        return False

async def check_all_channels_membership(user_id, channel_list, bot_token):
    if not channel_list:
        return True, ""
    
    missing_channels = []
    
    for channel in channel_list:
        channel = channel.strip()
        if not channel:
            continue
            
        is_member = await is_member_of_channel(user_id, channel, bot_token)
        if not is_member:
            missing_channels.append(channel)
    
    if missing_channels:
        return False, missing_channels
    return True, ""

async def set_bot_commands(application):
    from telegram import BotCommand
    
    commands = [
        BotCommand("start", "开始使用机器人"),
        BotCommand("stats", "查看统计信息（管理员）"),
        BotCommand("help", "获取帮助信息")
    ]
    
    try:
        await application.bot.set_my_commands(commands)
        logger.info("机器人命令设置成功")
    except Exception as e:
        logger.error(f"设置命令时出错: {e}")

async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    
    if REQUIRED_CHANNELS:
        is_member, missing_channels = await check_all_channels_membership(user.id, REQUIRED_CHANNELS, BOT_TOKEN)
        if not is_member:
            channels_text = ""
            for channel in missing_channels:
                if channel.startswith('@'):
                    channels_text += f"• https://t.me/{channel[1:]}\n"
                else:
                    channels_text += f"• 频道ID: {channel}\n"
            
            await update.message.reply_text(
                f"❌ 抱歉，您需要先加入以下频道才能使用此机器人：\n\n"
                f"{channels_text}\n"
                f"加入后请再次发送 /start 命令。",
                parse_mode=ParseMode.HTML,
                disable_web_page_preview=True
            )
            return
    
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
        "所有内容都会转发到指定群组。\n"
        "此服务由 @Lxi0707  脚本搭建，频道：@jijiijjji\n\n"
        "使用 /help 查看帮助信息"
    )

async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    help_text = (
        "🤖 <b>机器人使用帮助</b>\n\n"
        "📝 <b>可用命令:</b>\n"
        "/start - 开始使用机器人\n"
        "/help - 显示此帮助信息\n"
        "/stats - 查看统计信息（仅管理员）\n\n"
        "📤 <b>支持的消息类型:</b>\n"
        "• 文本消息\n"
        "• 图片/照片\n"
        "• 视频\n"
        "• 文件/文档\n"
        "• 语音消息\n"
        "• 贴纸\n\n"
        "⚠️ <b>注意事项:</b>\n"
        "• 所有消息都会转发到管理群组\n"
        "• 请勿发送垃圾信息\n"
        "• 大文件可能无法转发\n\n"
        "如有问题，请联系管理员。"
    )
    
    await update.message.reply_text(help_text, parse_mode=ParseMode.HTML)

async def handle_private_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.message.chat.type != "private":
        return
    
    user = update.effective_user
    
    if REQUIRED_CHANNELS:
        is_member, missing_channels = await check_all_channels_membership(user.id, REQUIRED_CHANNELS, BOT_TOKEN)
        if not is_member:
            channels_text = ""
            for channel in missing_channels:
                if channel.startswith('@'):
                    channels_text += f"• https://t.me/{channel[1:]}\n"
                else:
                    channels_text += f"• 频道ID: {channel}\n"
            
            await update.message.reply_text(
                f"❌ 抱歉，您需要先加入以下频道才能使用此机器人：\n\n"
                f"{channels_text}\n"
                f"加入后请再次发送消息。",
                parse_mode=ParseMode.HTML,
                disable_web_page_preview=True
            )
            return
    
    message = update.message
    record_user_usage(user.id, user.username, user.first_name, user.last_name)
    
    user_info = f"来自用户: {user.first_name}"
    if user.username:
        user_info += f" (@{user.username})"
    user_info += f"\n用户ID: {user.id}"
    
    try:
        if message.text:
            forward_text = f"{user_info}\n\n消息内容:\n{message.text}"
            await context.bot.send_message(
                chat_id=GROUP_CHAT_ID,
                text=forward_text,
                parse_mode=ParseMode.HTML
            )
            
        elif message.photo:
            caption = f"{user_info}\n\n图片消息"
            if message.caption:
                caption += f"\n描述: {message.caption}"
            
            photo_file = await message.photo[-1].get_file()
            await context.bot.send_photo(
                chat_id=GROUP_CHAT_ID,
                photo=photo_file.file_id,
                caption=caption
            )
            
        elif message.video:
            caption = f"{user_info}\n\n视频消息"
            if message.caption:
                caption += f"\n描述: {message.caption}"
            
            await context.bot.send_video(
                chat_id=GROUP_CHAT_ID,
                video=message.video.file_id,
                caption=caption
            )
            
        elif message.document:
            caption = f"{user_info}\n\n文件: {message.document.file_name}"
            if message.caption:
                caption += f"\n描述: {message.caption}"
            
            await context.bot.send_document(
                chat_id=GROUP_CHAT_ID,
                document=message.document.file_id,
                caption=caption
            )
            
        elif message.voice:
            caption = f"{user_info}\n\n语音消息"
        
            await context.bot.send_voice(
                chat_id=GROUP_CHAT_ID,
                voice=message.voice.file_id,
                caption=caption
            )
            
        elif message.sticker:
            caption = f"{user_info}\n\n发送了贴纸"
        
            await context.bot.send_sticker(
                chat_id=GROUP_CHAT_ID,
                sticker=message.sticker.file_id
            )
        
            await context.bot.send_message(
                chat_id=GROUP_CHAT_ID,
                text=caption
            )
            
        elif message.audio:
            caption = f"{user_info}\n\n音频文件"
            if message.caption:
                caption += f"\n描述: {message.caption}"
            
            await context.bot.send_audio(
                chat_id=GROUP_CHAT_ID,
                audio=message.audio.file_id,
                caption=caption
            )
        
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
        elif "httpx" in str(e).lower():
            error_msg += "（网络连接问题，请稍后重试）"
        await message.reply_text(error_msg)

async def stats_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    
    if user.id != ADMIN_USER_ID:
        await update.message.reply_text("❌ 抱歉，您没有权限执行此命令。")
        return
    
    conn = sqlite3.connect(DATABASE_NAME)
    cursor = conn.cursor()
    
    cursor.execute("SELECT COUNT(*) FROM user_usage")
    total_users = cursor.fetchone()[0]
    
    cursor.execute("SELECT SUM(usage_count) FROM user_usage")
    total_messages = cursor.fetchone()[0] or 0
    
    cursor.execute("SELECT username, first_name, last_name, usage_count FROM user_usage ORDER BY usage_count DESC LIMIT 5")
    top_users = cursor.fetchall()
    
    conn.close()
    
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
    logger.error(f"机器人错误: {context.error}")
    
    try:
        error_message = f"⚠️ 机器人错误:\n{context.error}"
        await context.bot.send_message(chat_id=ADMIN_USER_ID, text=error_message)
    except Exception as e:
        logger.error(f"发送错误报告失败: {e}")

def main():
    init_database()
    
    application = Application.builder().token(BOT_TOKEN).build()
    
    application.add_handler(CommandHandler("start", start_command))
    application.add_handler(CommandHandler("stats", stats_command))
    application.add_handler(CommandHandler("help", help_command))
    
    application.add_handler(MessageHandler(
        filters.ChatType.PRIVATE & (
            filters.TEXT | filters.PHOTO | filters.VIDEO | 
            filters.Document.ALL | filters.VOICE | filters.Sticker.ALL |
            filters.AUDIO
        ),
        handle_private_message
    ))
    
    application.add_error_handler(error_handler)
    
    application.post_init = set_bot_commands
    
    logger.info("🤖 机器人启动中...")
    print("🤖 机器人已启动！按 Ctrl+C 停止")
    
    try:
        application.run_polling()
    except httpx.ReadError as e:
        logger.error(f"网络连接错误: {e}")
        print("网络连接出现问题，请检查网络后重试")
    except Exception as e:
        logger.error(f"机器人运行错误: {e}")
        print(f"机器人运行错误: {e}")

if __name__ == "__main__":
    main()
EOL

    echo "创建启动脚本..."
    cat > "$INSTALL_DIR/start_bot.sh" << 'EOL'
#!/bin/bash
cd /root/telegram-bot
source /root/telegram-bot/bot-env/bin/activate
python /root/telegram-bot/telegram_bot.py
EOL

    chmod +x "$INSTALL_DIR/start_bot.sh"

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

view_status() {
    clear
    echo "=== 机器人状态 ==="
    
    systemctl status telegram-bot --no-pager -l
    
    echo ""
    read -p "按回车键返回菜单..."
}

view_logs() {
    clear
    echo "=== 查看日志 ==="
    echo "1. 查看最近20条日志"
    echo "2. 实时查看日志"
    echo "3. 查看错误日志"
    echo "0. 返回主菜单"
    echo ""
    
    read -p "请选择: " log_choice
    
    case $log_choice in
        1)
            echo "最近20条日志:"
            journalctl -u telegram-bot -n 20 --no-pager
            ;;
        2)
            echo "开始实时查看日志 (按 Ctrl+C 退出)..."
            journalctl -u telegram-bot -f
            ;;
        3)
            echo "错误日志:"
            journalctl -u telegram-bot --since "1 hour ago" -p err --no-pager
            ;;
        0)
            return
            ;;
        *)
            echo "无效选择"
            ;;
    esac
    
    echo ""
    read -p "按回车键返回菜单..."
}

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
    
    if [ -f ~/.bashrc ]; then
        sed -i '/alias botm=/d' ~/.bashrc
        echo "已删除alias配置"
    fi
    
    if [ -f "$SCRIPT_FILE" ]; then
        rm -f "$SCRIPT_FILE"
        echo "已删除管理脚本: $SCRIPT_FILE"
    fi
    
    echo ""
    echo "管理脚本已卸载完成！"
    echo "注意：机器人服务仍然存在，如需卸载机器人请先使用选项9"
    sleep 3
    
    exit 0
}

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
            8) view_logs ;;
            9) uninstall_bot ;;
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

if [ "$EUID" -ne 0 ]; then 
    echo "请使用root权限运行此脚本"
    exit 1
fi

main
