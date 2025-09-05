#!/bin/bash

# Telegram 消息转发机器人一键安装脚本
# 适用于美国服务器

echo "🚀 开始安装 Telegram 消息转发机器人..."

# 更新系统
echo "📦 更新系统包..."
sudo apt update && sudo apt upgrade -y

# 安装必要的依赖
echo "📦 安装依赖..."
sudo apt install -y python3 python3-pip python3-venv git

# 创建项目目录
echo "📁 创建项目目录..."
mkdir -p ~/telegram-bot
cd ~/telegram-bot

# 创建虚拟环境
echo "🐍 创建Python虚拟环境..."
python3 -m venv bot-env
source bot-env/bin/activate

# 安装必要的Python包
echo "📦 安装Python依赖..."
pip install python-telegram-bot sqlite3

# 创建配置文件
echo "⚙️ 创建配置文件..."
cat > bot_config.py << 'EOL'
# 机器人配置
BOT_TOKEN = "8408900332:AAFmroWfxm46-kb-ab0PtjApP5TK3gSdg4M"  # 您的机器人token
ADMIN_USER_ID = 6553906322  # 您的用户ID
GROUP_CHAT_ID = -1003009478386  # 目标群组ID
DATABASE_NAME = "bot_usage.db"
EOL

# 创建主程序文件
echo "💻 创建主程序文件..."
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
            f"总消息数: {total_messages}\n\n"
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
        f"总消息数: {total_messages}\n\n"
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
echo "📜 创建启动脚本..."
cat > start_bot.sh << 'EOL'
#!/bin/bash
cd ~/telegram-bot
source bot-env/bin/activate
python telegram_bot.py
EOL

chmod +x start_bot.sh

# 创建systemd服务文件
echo "🔧 创建systemd服务..."
sudo tee /etc/systemd/system/telegram-bot.service > /dev/null << EOL
[Unit]
Description=Telegram Message Forwarding Bot
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=/home/$USER/telegram-bot
ExecStart=/home/$USER/telegram-bot/start_bot.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOL

# 重新加载systemd并启动服务
echo "🚀 启动机器人服务..."
sudo systemctl daemon-reload
sudo systemctl enable telegram-bot
sudo systemctl start telegram-bot

echo "✅ 安装完成！"
echo "📋 检查服务状态: sudo systemctl status telegram-bot"
echo "📋 查看日志: sudo journalctl -u telegram-bot -f"
echo "📋 停止服务: sudo systemctl stop telegram-bot"
echo "📋 重启服务: sudo systemctl restart telegram-bot"
