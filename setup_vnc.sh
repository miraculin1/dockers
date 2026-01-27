#!/bin/bash
set -e

DE="${DE:-xfce}"   # xfce | lxde | mate | gnome
DISPLAY_NUM=":1"
VNC_PORT="5901"

echo "=== 1. 安装必要软件包 ==="
sudo apt update
sudo apt install -y git openssh-server dbus-x11 tigervnc-standalone-server

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
    # gnome-shell + gnome-session 是关键；x11-xserver-utils 提供 xsetroot 等工具（部分场景有用）
    sudo apt install -y gnome-session gnome-shell gnome-terminal x11-xserver-utils
    # GNOME 强制走 X11 会话
    START_CMD="gnome-session --session=gnome-xorg"
    ;;
  *)
    echo "Unsupported DE: $DE (use xfce|lxde|mate|gnome)"
    exit 1
    ;;
esac

echo "=== 2. 确保 SSH 服务启动并开机自启 ==="
sudo systemctl enable ssh
sudo systemctl restart ssh

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

xrdb "$HOME/.Xresources" 2>/dev/null

# 可选：给根窗口设个背景色，避免“全黑”时不确定是否起了 X
command -v xsetroot >/dev/null 2>&1 && xsetroot -solid grey

# 用 dbus-launch 包住 GNOME 会话
exec dbus-launch --exit-with-session gnome-session --session=gnome-xorg
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
tigervncserver $DISPLAY_NUM

echo "=== 7. 启动 noVNC 代理（Web 访问）==="
"$HOME/novnc/noVNC/utils/novnc_proxy" --vnc "localhost:$VNC_PORT"

