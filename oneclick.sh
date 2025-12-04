#!/bin/bash

set -e

echo "=== 1. 安装必要软件包 ==="
sudo apt update
sudo apt install -y x11vnc novnc websockify git openssh-server
sudo apt install -y tightvncserver gnome-session novnc websockify

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
echo -e '#!/bin/sh\nxrdb $HOME/.Xresources\nxsetroot -solid grey\ngnome-session &' > ~/.vnc/xstartup
chmod +x ~/.vnc/xstartup

vncserver :1
bash /usr/share/novnc/utils/launch.sh --vnc localhost:5901 &
