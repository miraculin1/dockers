#!/usr/bin/env bash
set -euo pipefail

USER_NAME="${USER_NAME:-ros}"
HOME_DIR="${HOME_DIR:-/home/${USER_NAME}}"

OLD_UID="${OLD_UID:-1000}"
OLD_GID="${OLD_GID:-1000}"

NEW_UID="${NEW_UID:?ERROR: NEW_UID is required}"
NEW_GID="${NEW_GID:?ERROR: NEW_GID is required}"

if [[ "$(id -u)" -ne 0 ]]; then
    echo "ERROR: This script must be run as root."
    exit 1
fi

if ! id "${USER_NAME}" >/dev/null 2>&1; then
    echo "ERROR: user '${USER_NAME}' does not exist."
    exit 1
fi

echo "[INFO] Target user : ${USER_NAME}"
echo "[INFO] Home dir    : ${HOME_DIR}"
echo "[INFO] Old UID/GID : ${OLD_UID}:${OLD_GID}"
echo "[INFO] New UID/GID : ${NEW_UID}:${NEW_GID}"

CURRENT_UID="$(id -u "${USER_NAME}")"
CURRENT_GID="$(id -g "${USER_NAME}")"

echo "[INFO] Current UID/GID of ${USER_NAME}: ${CURRENT_UID}:${CURRENT_GID}"

# 1. 修改 /etc/group 中 ros 用户主组的 GID
if getent group "${USER_NAME}" >/dev/null 2>&1; then
    echo "[INFO] Updating /etc/group for group '${USER_NAME}'..."
    sed -i -E "s#^(${USER_NAME}:[^:]*:)[0-9]+:#\1${NEW_GID}:#" /etc/group
else
    echo "[WARN] Group '${USER_NAME}' does not exist, skipping /etc/group update."
fi

# 2. 修改 /etc/passwd 中 ros 用户的 UID/GID
echo "[INFO] Updating /etc/passwd for user '${USER_NAME}'..."
sed -i -E "s#^(${USER_NAME}:[^:]*:)[0-9]+:[0-9]+:#\1${NEW_UID}:${NEW_GID}:#" /etc/passwd

# 3. 如果存在 /etc/subuid / /etc/subgid，可以选择性更新
if [[ -f /etc/subuid ]]; then
    sed -i -E "s#^(${USER_NAME}:)[0-9]+:#\1${NEW_UID}:#" /etc/subuid || true
fi

if [[ -f /etc/subgid ]]; then
    sed -i -E "s#^(${USER_NAME}:)[0-9]+:#\1${NEW_GID}:#" /etc/subgid || true
fi

# 4. 修复 home 目录下旧 UID/GID 文件的归属
if [[ -d "${HOME_DIR}" ]]; then
    echo "[INFO] Changing file ownership under ${HOME_DIR}..."

    find "${HOME_DIR}" -xdev \( -user "${OLD_UID}" -o -group "${OLD_GID}" \) -print0 \
        | xargs -0 -r -n 200 -P "$(nproc)" chown -- "${NEW_UID}:${NEW_GID}"

    echo "[INFO] Ownership update finished."
else
    echo "[WARN] Home directory '${HOME_DIR}' does not exist, skipping chown."
fi

# 5. 确保 home 目录本身归属正确
if [[ -d "${HOME_DIR}" ]]; then
    chown "${NEW_UID}:${NEW_GID}" "${HOME_DIR}"
fi

echo "[INFO] Done."
echo "[INFO] New identity:"
id "${USER_NAME}"
