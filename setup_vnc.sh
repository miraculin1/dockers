#!/bin/bash
set -euo pipefail

is_ssh_session() {
  [[ -n "${SSH_CONNECTION:-}" || -n "${SSH_TTY:-}" ]]
}

# ------------------------------------------------------------
# Options (env-driven)
# ------------------------------------------------------------
# Supported DE:
#   xfce | lxde | mate | gnome | openbox
DE="${DE:-openbox}"

DISPLAY_NUM="${DISPLAY_NUM:-:1}"

#   :1 -> 5901, :2 -> 5902, ...
if [[ -z "${VNC_PORT+x}" ]]; then
  dn="${DISPLAY_NUM#:}"   # strip leading ':'
  dn="${dn:-1}"
  if [[ ! "$dn" =~ ^[0-9]+$ ]]; then
    echo "[ERROR] DISPLAY_NUM must be like :1 or 1, got: '$DISPLAY_NUM'"
    exit 1
  fi
  VNC_PORT=$((5900 + dn))
fi

NOVNC_PORT="${NOVNC_PORT:-6080}"

# TigerVNC desktop geometry/depth
SCREEN_RES="${SCREEN_RES:-1920x1080}"
SCREEN_DPI="${SCREEN_DPI:-96}"
SCREEN_DEPTH="${SCREEN_DEPTH:-24}"

# VirtualGL toggle
ENABLE_VGL="${ENABLE_VGL:-0}"
VGL_DEVICE="${VGL_DEVICE:-:0}"
RUN_GUI=""   # set when vgl enabled

# Desktop session start command for xstartup
START_CMD=""

echo "=== 0. Install base packages ==="
sudo apt update
sudo apt install -y \
  git dbus-x11 \
  tigervnc-standalone-server \
  xterm x11-xserver-utils

# Optional: OpenSSH (only if not already in SSH session)
if is_ssh_session; then
  echo "[INFO] SSH session detected; skip installing openssh-server."
else
  echo "[INFO] Not an SSH session; installing openssh-server..."
  sudo apt-get update
  sudo apt-get install -y --no-install-recommends openssh-server
fi

# VirtualGL (optional)
if [[ "$ENABLE_VGL" == "1" ]]; then
  echo "=== 0.1 Enable VirtualGL (vglrun) ==="
  sudo apt install -y virtualgl
  RUN_GUI="vglrun -d ${VGL_DEVICE}"
  echo "[INFO] VirtualGL enabled. RUN_GUI='${RUN_GUI}'"
else
  echo "[INFO] VirtualGL disabled. Set ENABLE_VGL=1 to enable."
fi

echo "=== 1. Install desktop / WM (DE=$DE) ==="
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
    sudo apt install -y gnome-session gnome-shell gnome-terminal
    START_CMD="gnome-session --session=gnome-xorg"
    ;;
  openbox)
    sudo apt install -y openbox
    START_CMD="openbox-session"
    ;;
  *)
    echo "Unsupported DE: $DE (use xfce|lxde|mate|gnome|openbox)"
    exit 1
    ;;
esac

echo "=== 2. Start SSH service (if applicable) ==="
if is_ssh_session; then
  echo "[INFO] SSH session detected; skip enabling sshd."
else
  sudo systemctl enable ssh || true
  sudo systemctl restart ssh || true
fi

echo "=== 3. Fetch noVNC + websockify (if missing) ==="
mkdir -p "$HOME/novnc"
cd "$HOME/novnc"
if [ ! -d "noVNC" ]; then
  git clone https://github.com/novnc/noVNC.git noVNC
else
  echo "[INFO] noVNC already exists; skip."
fi
if [ ! -d "websockify" ]; then
  git clone https://github.com/novnc/websockify.git websockify
else
  echo "[INFO] websockify already exists; skip."
fi

echo "=== 4. VNC password (interactive, only first time) ==="
mkdir -p ~/.vnc
if [ ! -f ~/.vnc/passwd ]; then
  vncpasswd
else
  echo "[INFO] ~/.vnc/passwd exists; skip."
fi

echo "=== 5. Ensure XDG_RUNTIME_DIR for container GUI apps ==="
export XDG_RUNTIME_DIR="/tmp/runtime-$(id -u)"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
chmod 1777 /tmp 2>/dev/null || true

write_xstartup() {
  local mode="$1"

  if [[ "$mode" == "gnome" ]]; then
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

# Minimal safety: ensure dbus session exists
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

start_tigervnc() {
  echo "=== 6. Start TigerVNC (Xvnc) on $DISPLAY_NUM (port $VNC_PORT) ==="

  # 清理旧实例
  tigervncserver -kill "$DISPLAY_NUM" 2>/dev/null || true

  # 建议显式传 geometry/depth，避免默认分辨率太小
  tigervncserver "$DISPLAY_NUM" \
    -geometry "$SCREEN_RES" \
    -depth "$SCREEN_DEPTH" \
    -dpi "$SCREEN_DPI"

  echo "[INFO] VNC display: $DISPLAY_NUM  (expected VNC port: $VNC_PORT)"
}

start_novnc() {
  echo "=== 7. Start noVNC proxy (Web -> VNC) ==="
  "$HOME/novnc/noVNC/utils/novnc_proxy" --listen "$NOVNC_PORT" --vnc "localhost:$VNC_PORT"
}

print_usage_hint() {
  echo "=== HINT: how to launch GUI apps ==="
  echo "[INFO] Access desktop via noVNC port: ${NOVNC_PORT}"
  echo "[INFO] Inside container, DISPLAY is typically ${DISPLAY_NUM}"
  if [[ "$ENABLE_VGL" == "1" ]]; then
    echo "[INFO] VirtualGL enabled. Launch GPU-accelerated OpenGL apps using:"
    echo "       \$RUN_GUI <gui_app>     (RUN_GUI='${RUN_GUI}')"
    echo "       Example: \$RUN_GUI glxinfo -B"
    echo "       Example: \$RUN_GUI ./isaac-sim.sh"
  else
    echo "[INFO] VirtualGL disabled. Launch apps normally, or set ENABLE_VGL=1."
  fi
}

echo "=== 6. Write xstartup and start session (DE=$DE) ==="
write_xstartup "$DE"
start_tigervnc
print_usage_hint
start_novnc

