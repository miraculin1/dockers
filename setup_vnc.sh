#!/bin/bash
set -euo pipefail

is_ssh_session() {
  [[ -n "${SSH_CONNECTION:-}" || -n "${SSH_TTY:-}" ]]
}

# 兼容你原来的参数：xfce|lxde|mate|gnome
# 新增：xorg|xvfb
DE="${DE:-xfce}"

DISPLAY_NUM="${DISPLAY_NUM:-:1}"
VNC_PORT="${VNC_PORT:-5901}"
NOVNC_PORT="${NOVNC_PORT:-6080}"

# Xorg/Xvfb 屏幕参数
SCREEN_RES="${SCREEN_RES:-1920x1080}"
SCREEN_DPI="${SCREEN_DPI:-96}"
SCREEN_DEPTH="${SCREEN_DEPTH:-24}"

# x11vnc 参数（可按需调整）
X11VNC_EXTRA="${X11VNC_EXTRA:-"-shared -forever -noxdamage -repeat -rfbport ${VNC_PORT}"}"

# 桌面启动命令（给 xfce/lxde/mate/gnome 用）
START_CMD=""

echo "=== 0. 基础依赖 ==="
sudo apt update
sudo apt install -y git dbus-x11 tigervnc-standalone-server

# xorg/xvfb 方案会用到（即使你用 xfce 也不影响）
sudo apt install -y x11vnc xterm x11-xserver-utils

if is_ssh_session; then
  echo "[INFO] Detected SSH session; skip installing openssh-server."
else
  echo "[INFO] Not an SSH session; installing openssh-server..."
  sudo apt-get update
  sudo apt-get install -y --no-install-recommends openssh-server
fi

echo "=== 1. 安装桌面/窗口管理器（按 DE）==="
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
  xorg)
    # 文档类“Xorg GPU 渲染容器”常见需要这些
    sudo apt install -y xorg xserver-xorg-core xserver-xorg-video-dummy openbox
    # openbox 作为轻量 WM，避免 GNOME/完整桌面带来的权限/依赖问题
    START_CMD="openbox-session"
    ;;
  xvfb)
    sudo apt install -y xvfb openbox
    START_CMD="openbox-session"
    ;;
  *)
    echo "Unsupported DE: $DE (use xfce|lxde|mate|gnome|xorg|xvfb)"
    exit 1
    ;;
esac

echo "=== 2. SSH 服务（如需要）==="
if is_ssh_session; then
  echo "[INFO] Detected SSH session; skip enable openssh-server."
else
  echo "[INFO] Not an SSH session; enable openssh-server..."
  sudo systemctl enable ssh || true
  sudo systemctl restart ssh || true
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
if [ ! -f ~/.vnc/passwd ]; then
  vncpasswd
else
  echo "检测到已有 ~/.vnc/passwd，跳过设置。"
fi

echo "=== 5. 统一准备运行时目录（容器常缺 /run/user/$UID）==="
export XDG_RUNTIME_DIR="/tmp/runtime-$(id -u)"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
chmod 1777 /tmp 2>/dev/null || true

write_xstartup_for_tigervnc() {
  local mode="$1"
  if [ "$mode" = "gnome" ]; then
    cat > ~/.vnc/xstartup <<'EOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

export XDG_SESSION_TYPE=x11
export GDK_BACKEND=x11
export QT_QPA_PLATFORM=xcb

export XDG_RUNTIME_DIR="/tmp/runtime-$(id -u)"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
chmod 1777 /tmp 2>/dev/null || true

xrdb "$HOME/.Xresources" 2>/dev/null
command -v xsetroot >/dev/null 2>&1 && xsetroot -solid grey

exec dbus-launch --exit-with-session gnome-session --session=gnome-xorg
EOF
  else
    cat > ~/.vnc/xstartup <<EOF
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export XDG_SESSION_TYPE=x11

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
}

kill_port() {
  local port="$1"
  if command -v fuser >/dev/null 2>&1; then
    sudo fuser -k "${port}/tcp" 2>/dev/null || true
  fi
}

start_novnc() {
  echo "=== 8. 启动 noVNC 代理（Web 访问）==="
  "$HOME/novnc/noVNC/utils/novnc_proxy" --listen "$NOVNC_PORT" --vnc "localhost:$VNC_PORT"
}

start_x11vnc_on_display() {
  local display="$1"
  echo "=== 7. 启动 x11vnc（导出 $display -> VNC:$VNC_PORT）==="
  kill_port "$VNC_PORT"
  nohup x11vnc -display "$display" -rfbauth "$HOME/.vnc/passwd" $X11VNC_EXTRA >/tmp/x11vnc.log 2>&1 &
  echo "[INFO] x11vnc log: /tmp/x11vnc.log"
}

start_xorg_dummy() {
  echo "=== 6. 启动 Xorg (dummy) 于 $DISPLAY_NUM ==="

  mkdir -p "$HOME/.xorg"
  cat > "$HOME/.xorg/xorg-dummy.conf" <<EOF
Section "Device"
  Identifier  "DummyDevice"
  Driver      "dummy"
  VideoRam    256000
EndSection

Section "Monitor"
  Identifier  "DummyMonitor"
  HorizSync   28.0-80.0
  VertRefresh 48.0-75.0
EndSection

Section "Screen"
  Identifier  "DummyScreen"
  Device      "DummyDevice"
  Monitor     "DummyMonitor"
  DefaultDepth ${SCREEN_DEPTH}
  SubSection "Display"
    Depth     ${SCREEN_DEPTH}
    Modes     "${SCREEN_RES}"
  EndSubSection
EndSection

Section "ServerLayout"
  Identifier  "DummyLayout"
  Screen      "DummyScreen"
EndSection
EOF

  pkill -f "Xorg ${DISPLAY_NUM}" 2>/dev/null || true
  sudo nohup Xorg "${DISPLAY_NUM}" -config "$HOME/.xorg/xorg-dummy.conf" -noreset -logfile /tmp/Xorg.log >/dev/null 2>&1 &
  echo "[INFO] Xorg log: /tmp/Xorg.log"
  sleep 1
}

start_xvfb() {
  echo "=== 6. 启动 Xvfb 于 $DISPLAY_NUM ==="
  pkill -f "Xvfb ${DISPLAY_NUM}" 2>/dev/null || true
  nohup Xvfb "${DISPLAY_NUM}" -screen 0 "${SCREEN_RES}x${SCREEN_DEPTH}" -dpi "${SCREEN_DPI}" >/tmp/Xvfb.log 2>&1 &
  echo "[INFO] Xvfb log: /tmp/Xvfb.log"
  sleep 1
}

start_light_session_on_display() {
  local display="$1"
  echo "=== 6.1 在 $display 上启动轻量会话（openbox + xterm）==="
  export DISPLAY="$display"

  if command -v dbus-launch >/dev/null 2>&1; then
    eval "$(dbus-launch --sh-syntax)"
    export DBUS_SESSION_BUS_ADDRESS DBUS_SESSION_BUS_PID
  fi

  command -v xsetroot >/dev/null 2>&1 && xsetroot -solid grey || true
  (command -v openbox-session >/dev/null 2>&1 && openbox-session >/tmp/openbox.log 2>&1 &) || true
  (command -v xterm >/dev/null 2>&1 && xterm -geometry 120x30+20+20 -fa Monospace -fs 12 >/tmp/xterm.log 2>&1 &) || true
}

echo "=== 6. 按模式启动 ==="
case "$DE" in
  xorg)
    start_xorg_dummy
    start_light_session_on_display "$DISPLAY_NUM"
    start_x11vnc_on_display "$DISPLAY_NUM"
    start_novnc
    ;;
  xvfb)
    start_xvfb
    start_light_session_on_display "$DISPLAY_NUM"
    start_x11vnc_on_display "$DISPLAY_NUM"
    start_novnc
    ;;
  *)
    echo "=== 6. 写入 xstartup（桌面：$DE）==="
    write_xstartup_for_tigervnc "$DE"

    echo "=== 7. 启动 VNC（Xvnc: $DISPLAY_NUM -> localhost:$VNC_PORT）==="
    tigervncserver -kill "$DISPLAY_NUM" 2>/dev/null || true
    tigervncserver "$DISPLAY_NUM"

    start_novnc
    ;;
esac

