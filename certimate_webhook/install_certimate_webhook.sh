#!/bin/bash

# 安装 certimate_webhook 二进制文件
# 运行此脚本：
# 从 github release 下载 latest 的 install.sh 脚本 并执行
# wget -qO- https://github.com/JaxhLee/raw_go/releases/latest/download/install_certimate_webhook.sh | bash

# 停止并禁用，忽略不存在时的错误输出
systemctl stop $SERVICE_NAME >/dev/null 2>&1
systemctl disable $SERVICE_NAME >/dev/null 2>&1

# 只有在删除 .service 文件后才必须执行 daemon-reload
# 如果只是重启，不需要频繁执行
systemctl daemon-reload
systemctl reset-failed $SERVICE_NAME >/dev/null 2>&1

# 生成随机密码
WEBHOOK_SECRET=$(openssl rand -hex 32)

# 从 github release 下载 latest 的 certimate_webhook 二进制文件
DOWNLOAD_URL="https://github.com/JaxhLee/raw_go/releases/latest/download/certimate_webhook_linux_amd64"
wget -O certimate_webhook_linux_amd64 $DOWNLOAD_URL

# 下载 certimate_webhook_config.template.yaml 配置文件
DOWNLOAD_URL="https://github.com/JaxhLee/raw_go/releases/latest/download/certimate_webhook_config.template.yaml"
wget -O certimate_webhook_config.template.yaml $DOWNLOAD_URL

# 创建 certimate_webhook 目录
mkdir -p /etc/certimate_webhook

# 移动二进制文件到 /etc/certimate_webhook/
mv certimate_webhook_linux_amd64 /etc/certimate_webhook/certimate_webhook
chmod +x /etc/certimate_webhook/certimate_webhook

# 移动配置文件到 /etc/certimate_webhook/
mv certimate_webhook_config.template.yaml /etc/certimate_webhook/config.yaml
# 按行替换 webhook-secret 为随机密码
sed -i "s#^webhook-secret:.*#webhook-secret: $WEBHOOK_SECRET#" /etc/certimate_webhook/config.yaml

# 创建 ssl 目录
mkdir -p /etc/certimate_webhook/ssl

# 创建 systemd 服务文件
cat <<EOF > /etc/systemd/system/certimate_webhook.service
[Unit]
Description=Certimate Webhook
After=network.target

[Service]
ExecStart=/etc/certimate_webhook/certimate_webhook -config /etc/certimate_webhook/config.yaml
StandardOutput=journal
StandardError=journal

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
