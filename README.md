***Tgbot消息转发🤖️***


注意：支持Debian/Ubuntu系统


# 预览：
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/Lxi0707/telegram-bot-installer/refs/heads/main/IMG_2985.jpeg">
  <source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/Lxi0707/telegram-bot-installer/refs/heads/main/IMG_2985.jpeg">
  <img alt="自定义图片" src="https://raw.githubusercontent.com/Lxi0707/telegram-bot-installer/refs/heads/main/IMG_2985.jpeg">
</picture>



**介绍**


用户使用bot，发送任意内容，bot识别后均可识别转发到指定的群组(可以添加绑定群组变量，添加后用户必须关注频道 ID/用户名 才可使用）


（绑定群组需要设置为管理员）

管理员可以使用 /stats 命令进行统计📉用户的使用次数


***使用教程***


管理员下载好 .sh 脚本，上传至服务器


**1.给执行权限**：
```bash
chmod +x bot_manager.sh
```


**2.运行脚本**：
```bash
./bot_manager.sh
```


**3.进去菜单，选择2配置参数**：
  1. 通过 @BotFather 创建一个新的 Telegram 机器人，获取 BOT_TOKEN
  2. 获取您的用户 ID（可以使用 @userinfobot）
  3. 获取目标群组的 ID（超级群组，ID 以 -100 开头）
  4. 频道绑定 ID/用户名


***编辑以下变量：***
· BOT_TOKEN: 您的机器人令牌
· ADMIN_USER_ID: 您的用户 ID
· GROUP_CHAT_ID: 目标群组的 ID
· REQUIRED_CHANNELS 频道绑定 ID/用户名（可选） 


| **变量名**                  | **说明**   | **示例**                                        
|-----------------------------|------------|--------------------------------------------------------------------------|
| `BOT_TOKEN`             | 从 @BotFather 获取    | `123456:ABC-DEF1234ghIkl`    |
| `ADMIN_USER_ID`               | 管理员用户ID   |  `123456789`     |
| `GROUP_CHAT_ID`       | 接受消息群组ID   | `-100123456789`            |
| `REQUIRED_CHANNELS`       | 用户必须加入的频道才可以使用bot（可选）功能：频道群组绑定，用户未关注无法使用   | `@channel1,-100123456789`            |



**4.配置完成后选择1安装机器人**


**5.安装完成选择启动机器人，转发服务即可启动**


⬇️⬇️⬇️


**支持所有媒体类型**


· ✅ 文本消息


· ✅ 图片/照片


· ✅ 视频


· ✅ 文件/文档


· ✅ 语音消息


· ✅ 贴纸


· ✅ 音频文件


本服务服务器由 极光云 提供，谢谢支持
