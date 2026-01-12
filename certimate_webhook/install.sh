#!/bin/bash

# 安装 certimate_webhook 二进制文件
# 运行此脚本：
# 从 github 下载 install.sh 脚本 并执行
# wget -qO- https://raw.githubusercontent.com/JaxhLee/raw_go/refs/heads/main/certimate_webhook/install.sh | bash

# 生成随机密码
WEBHOOK_SECRET=$(openssl rand -hex 32)

# 从 github 下载 certimate_webhook 二进制文件
DOWNLOAD_URL="https://raw.githubusercontent.com/JaxhLee/raw_go/refs/heads/main/certimate_webhook/certimate_webhook_linux_amd64"
wget -O certimate_webhook_linux_amd64 $DOWNLOAD_URL

# 创建 certimate_webhook 目录
mkdir -p /etc/certimate_webhook

# 移动二进制文件到 /etc/certimate_webhook/
mv certimate_webhook_linux_amd64 /etc/certimate_webhook/certimate_webhook
chmod +x /etc/certimate_webhook/certimate_webhook

# 创建 ssl 目录
mkdir -p /etc/certimate_webhook/ssl

# 创建 systemd 服务文件
cat <<EOF > /etc/systemd/system/certimate_webhook.service
[Unit]
Description=Certimate Webhook
After=network.target

[Service]
ExecStart=/etc/certimate_webhook/certimate_webhook -port 8080 -webhook-url /webhook -webhook-secret $WEBHOOK_SECRET -storage-path /etc/certimate_webhook/ssl

[Install]
WantedBy=multi-user.target
EOF

# 启动服务
systemctl daemon-reload
systemctl enable certimate_webhook
systemctl start certimate_webhook

# 显示服务状态
systemctl status certimate_webhook

# 显示服务日志
journalctl -u certimate_webhook -f

# 显示安装成功
echo "certimate_webhook 安装成功"
