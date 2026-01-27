#!/bin/bash
set -e

echo "=== 1. 安装必要软件包 ==="
sudo apt update
sudo apt install -y git openssh-server
sudo apt install -y tightvncserver gnome-session

echo "=== 2. 确保 SSH 服务启动并开机自启 ==="
sudo systemctl enable ssh
sudo systemctl restart ssh
echo "SSH服务已启动并设置为开机自启。"

echo "=== 3. 下载 noVNC 和 websockify ==="
# 如果 noVNC 已经存在，跳过clone
if [ ! -d "noVNC" ]; then
  git clone https://github.com/novnc/noVNC.git .
else
  echo "检测到已有 noVNC，跳过下载。"
fi

echo "=== 4. 设置 VNC 密码==="
mkdir -p ~/.vnc

vncpasswd

cat > ~/.vnc/xstartup <<'EOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export XDG_SESSION_TYPE=x11
export GDK_BACKEND=x11
export QT_QPA_PLATFORM=xcb

xrdb "$HOME/.Xresources" 2>/dev/null
dbus-launch --exit-with-session gnome-session --session=gnome-xorg
EOF

tightvncserver :1
noVNC/utils/novnc_proxy --vnc localhost:5901
