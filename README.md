# 容器
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

在使用的时候有几个常用 ssh 参数
- `-N -L l_port:r_ip:r_port user@host`用于端口转发，访问跳板机后面的服务
- `-R` 将远端的请求经过本地代理
- `-D` 将本地的请求交给远端代理，用于给跳板机登录校园网

# setup_vnc.sh
*目前远程桌面使用novnc以后可以折腾一下sunshine+moonlight*

- 容器需要有 privilege 权限才能启动
