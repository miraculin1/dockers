1. 选择版本
2. 修改镜像内用户 uid 以适配本地用户
3. `bash build.sh <name>` 构建镜像
4. 启动时为了保证 gui 以及显卡调用 `bash run_docker_gui.sh <name>`

值得注意的：
- 当需要后续修改容器内 UID 以及 GID，以 root 启动容器，然后运行以下命令
``` bash
usermod -u ${NEW_UID} -g ${NEW_GID}
groupdel ros
groupadd -g ${NEW_GID} ros

find /home/ros -xdev \( -user 1000 -o -group 1000 \) -print0 \
  | xargs -0 -r -n 200 -P "$(nproc)" chown -- 1001:1001

# 强力修改用户 uid gid
sed -i -E "s#^(ros:[^:]*:)[0-9]+:[0-9]+:#\1${NEW_UID}:${NEW_GID}:#" /etc/passwd && \

```
