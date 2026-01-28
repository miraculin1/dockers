#!/bin/bash
set -e

is_ssh_session() {
  [[ -n "${SSH_CONNECTION:-}" || -n "${SSH_TTY:-}" ]]
}

DE="${DE:-xfce}"   # xfce | lxde | mate | gnome | xonly
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
    # GNOME 在 VNC/Xvnc 下需要的组件更全一些
    sudo apt install -y gnome-session gnome-shell gnome-terminal x11-xserver-utils
    START_CMD="gnome-session --session=gnome-xorg"
    ;;
  xonly)
    # 只提供“虚拟屏幕 + 可交互窗口”，不启动完整桌面（适合 seccomp 禁 close_range 的环境）
    sudo apt install -y xterm x11-xserver-utils
    START_CMD=""
    ;;
  *)
    echo "Unsupported DE: $DE (use xfce|lxde|mate|gnome|xonly)"
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
# GNOME on VNC: 尽量提供完整的 X11 session 环境
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

export XDG_SESSION_TYPE=x11
export GDK_BACKEND=x11
export QT_QPA_PLATFORM=xcb

# 运行时目录（容器常缺 /run/user/$UID）
export XDG_RUNTIME_DIR="/tmp/runtime-$(id -u)"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
chmod 1777 /tmp 2>/dev/null || true

xrdb "$HOME/.Xresources" 2>/dev/null
command -v xsetroot >/dev/null 2>&1 && xsetroot -solid grey

exec dbus-launch --exit-with-session gnome-session --session=gnome-xorg
EOF

elif [ "$DE" = "xonly" ]; then
  cat > ~/.vnc/xstartup <<'EOF'
#!/bin/sh
# xonly: 只提供 Xvnc 虚拟屏幕 + 一个可交互窗口，不启动桌面环境
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

# 运行时目录（容器常缺 /run/user/$UID）
export XDG_RUNTIME_DIR="/tmp/runtime-$(id -u)"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
chmod 1777 /tmp 2>/dev/null || true

xrdb "$HOME/.Xresources" 2>/dev/null
command -v xsetroot >/dev/null 2>&1 && xsetroot -solid grey

# 给你一个可见窗口（便于交互/排查；之后你也可以从 SSH 里 export DISPLAY=:1 跑任意 GUI）
command -v xterm >/dev/null 2>&1 && xterm -geometry 120x30+20+20 -fa Monospace -fs 12 &

# 可选：给一些 GUI 程序提供 session bus
if command -v dbus-launch >/dev/null 2>&1; then
  eval "$(dbus-launch --sh-syntax)"
  export DBUS_SESSION_BUS_ADDRESS DBUS_SESSION_BUS_PID
fi

# 常驻，保持会话不退出
exec tail -f /dev/null
EOF

else
  cat > ~/.vnc/xstartup <<EOF
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export XDG_SESSION_TYPE=x11

# 运行时目录（容器常缺 /run/user/\$UID）
export XDG_RUNTIME_DIR="/tmp/runtime-\$(id -u)"
mkdir -p "\$XDG_RUNTIME_DIR"
chmod 700 "\$XDG_RUNTIME_DIR"
chmod 1777 /tmp 2>/dev/null || true

xrdb "\$HOME/.Xresources" 2>/dev/null
command -v xsetroot >/dev/null 2>&1 && xsetroot -solid grey

exec dbus-launch --exit-with-session $START_CMD
EOF
fi

chmod +x ~/.vnc/xstartup

echo "=== 6. 启动 VNC ==="
tigervncserver -kill $DISPLAY_NUM 2>/dev/null || true
tigervncserver $DISPLAY_NUM

echo "=== 7. 启动 noVNC 代理（Web 访问）==="
"$HOME/novnc/noVNC/utils/novnc_proxy" --vnc "localhost:$VNC_PORT"

