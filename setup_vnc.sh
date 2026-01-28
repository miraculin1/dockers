#!/bin/bash
set -e

is_ssh_session() {
  [[ -n "${SSH_CONNECTION:-}" || -n "${SSH_TTY:-}" ]]
}

DE="${DE:-xfce}"   # xfce | lxde | mate | gnome | openbox
DISPLAY_NUM=":1"
VNC_PORT="5901"

echo "=== 1. 安装必要软件包 ==="
sudo apt update
sudo apt install -y git dbus-x11 tigervnc-standalone-server

if is_ssh_session; then
  echo "[INFO] Detected SSH session; skip installing openssh-server."
else
  echo "[INFO] Not an SSH session; installing openssh-server..."
  apt-get update
  apt-get install -y --no-install-recommends openssh-server
fi

case "$DE" in
  xfce)
    sudo apt install -y xfce4 xfce4-goodies
    START_CMD="startxfce4"
    ;;
  lxde)
    sudo apt install -y lxde
    START_CMD="startlxde"
    ;;
  mate)
    sudo apt install -y mate-desktop-environment-core
    START_CMD="mate-session"
    ;;
  gnome)
    sudo apt install -y gnome-session gnome-shell gnome-terminal x11-xserver-utils
    START_CMD="gnome-session --session=gnome-xorg"
    ;;
  openbox)
    # AutoDL/seccomp 场景更稳：轻量 WM + 一个终端
    sudo apt install -y openbox xterm x11-xserver-utils
    START_CMD="openbox-session"
    ;;
  *)
    echo "Unsupported DE: $DE (use xfce|lxde|mate|gnome|openbox)"
    exit 1
    ;;
esac

echo "=== 2. 确保 SSH 服务启动并开机自启 ==="
if is_ssh_session; then
  echo "[INFO] Detected SSH session; skip enable openssh-server."
else
  echo "[INFO] Not an SSH session; enable openssh-server..."
  sudo systemctl enable ssh
  sudo systemctl restart ssh
fi

echo "=== 3. 下载 noVNC 和 websockify ==="
mkdir -p "$HOME/novnc"
cd "$HOME/novnc"
if [ ! -d "noVNC" ]; then
  git clone https://github.com/novnc/noVNC.git noVNC
else
  echo "检测到已有 noVNC，跳过下载。"
fi
if [ ! -d "websockify" ]; then
  git clone https://github.com/novnc/websockify.git websockify
else
  echo "检测到已有 websockify，跳过下载。"
fi

echo "=== 4. 设置 VNC 密码（交互式）==="
mkdir -p ~/.vnc
vncpasswd

echo "=== 5. 写入 xstartup（桌面：$DE）==="
if [ "$DE" = "gnome" ]; then
  cat > ~/.vnc/xstartup <<'EOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

export XDG_SESSION_TYPE=x11
export GDK_BACKEND=x11
export QT_QPA_PLATFORM=xcb

xrdb "$HOME/.Xresources" 2>/dev/null
command -v xsetroot >/dev/null 2>&1 && xsetroot -solid grey

exec dbus-launch --exit-with-session gnome-session --session=gnome-xorg
EOF

elif [ "$DE" = "openbox" ]; then
  # openbox：强烈建议起一个 xterm，避免“只有背景像黑屏”
  cat > ~/.vnc/xstartup <<'EOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export XDG_SESSION_TYPE=x11

xrdb "$HOME/.Xresources" 2>/dev/null
command -v xsetroot >/dev/null 2>&1 && xsetroot -solid grey

# 给你一个可见的窗口
command -v xterm >/dev/null 2>&1 && xterm &

# 常驻会话：一定要 exec
exec dbus-launch --exit-with-session openbox-session
EOF

else
  cat > ~/.vnc/xstartup <<EOF
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export XDG_SESSION_TYPE=x11

xrdb "\$HOME/.Xresources" 2>/dev/null
exec dbus-launch --exit-with-session $START_CMD
EOF
fi

chmod +x ~/.vnc/xstartup

echo "=== 6. 启动 VNC ==="
tigervncserver -kill $DISPLAY_NUM 2>/dev/null || true
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 ~/.vnc/*:1.pid ~/.vnc/*:1.log 2>/dev/null || true
tigervncserver $DISPLAY_NUM

echo "=== 7. 启动 noVNC 代理（Web 访问）==="
"$HOME/novnc/noVNC/utils/novnc_proxy" --vnc "localhost:$VNC_PORT"

