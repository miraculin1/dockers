#!/bin/bash

set -e

echo "=== 1. 安装必要软件包 ==="
sudo apt update
sudo apt install -y x11vnc novnc websockify git openssh-server

echo "=== 2. 确保 SSH 服务启动并开机自启 ==="
sudo systemctl enable ssh
sudo systemctl restart ssh
echo "SSH服务已启动并设置为开机自启。"

echo "=== 3. 创建 noVNC 目录（如果不存在） ==="
mkdir -p ~/novnc
cd ~/novnc

echo "=== 4. 下载 noVNC 和 websockify ==="
# 如果 noVNC 已经存在，跳过clone
if [ ! -d "./utils/websockify" ]; then
  git clone https://github.com/novnc/noVNC.git .
  git clone https://github.com/novnc/websockify.git ./utils/websockify
else
  echo "检测到已有 noVNC，跳过下载。"
fi

echo "=== 5. 设置 VNC 密码（默认123456）==="
mkdir -p ~/.vnc
x11vnc -storepasswd 123456 ~/.vnc/passwd

echo "=== 6. 创建 noVNC 的 systemd 服务文件 ==="

SERVICE_FILE=/etc/systemd/system/novnc.service

sudo bash -c "cat > $SERVICE_FILE" <<EOF
[Unit]
Description=noVNC server
After=network.target graphical.target

[Service]
Type=simple
ExecStart=/bin/bash -c 'x11vnc -forever -usepw -display :0 -shared -rfbport 5900 & sleep 2 && ~/novnc/utils/novnc_proxy --vnc localhost:5900 --listen 6080'
User=$USER
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

echo "=== 7. 重新加载 systemd 配置并启动 noVNC 服务 ==="
sudo systemctl daemon-reload
sudo systemctl enable novnc
sudo systemctl restart novnc

echo "=== 8. 完成！==="

echo ">>> SSH 已开启，使用 ssh $USER@<IP地址> 登录"
echo ">>> noVNC 已开启，访问 http://<IP地址>:6080/vnc.html 浏览器查看桌面"
echo "默认 VNC 密码是 123456（可以后续自己修改 ~/.vnc/passwd）"

