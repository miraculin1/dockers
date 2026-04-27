# 容器
## 前置依赖
- 需要提前安装 `docker` 与 `nvidia-container-toolkit`。
- 建议先做最小可用性检查：
```bash
docker --version
nvidia-smi
docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu20.04 nvidia-smi
```

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

## Miniforge 使用说明
如果容器内已安装 Miniforge（默认路径 `~/miniforge3`），可按以下步骤初始化并启用：

```bash
source ~/miniforge3/bin/activate
conda init --all
```

执行 `conda init --all` 后，建议重新打开一个 shell 以确保初始化脚本生效。

在使用 `run_docker_gui.sh` 启动并正确透传 X11 的前提下，`rviz`、`rqt` 等可视化窗口可在本机或远程桌面环境中无缝显示与交互。

## cuda11_8_ROS 使用说明
### 1) 构建镜像
进入目录后执行：
```bash
cd cuda11_8_ROS
bash build.sh <image_name>
```
`build.sh` 会执行 `docker build --network host`，并透传本机的 `http_proxy` 与 `https_proxy` 到构建参数。

### 2) 创建并进入容器
```bash
cd cuda11_8_ROS
bash run_docker_gui.sh <container_name>
```
`run_docker_gui.sh` 会使用以下关键参数启动容器：
- `--gpus all`
- `--network=host --ipc=host`
- X11 相关挂载与环境变量（`/tmp/.X11-unix`、`DISPLAY`）
- `--privileged`
- `--user ros`
- `--ulimit nofile=1024:524288`

注意：该脚本固定使用镜像 `cuda11_8_ros:latest` 启动容器。如果你构建时使用了其他镜像名，请确保标签一致（例如直接构建为 `cuda11_8_ros:latest`），否则运行脚本会找不到镜像。

### 3) mnt 软链接挂载逻辑（重点）
`run_docker_gui.sh` 使用了：
```bash
-v $(pwd)/mnt:/workspace
```
该设计的核心意图是：在容器实例创建后，仍能通过调整 `mnt` 软链接目标，灵活修改容器内 `/workspace` 可见的目录范围。

这意味着：
- 你必须在 `cuda11_8_ROS` 目录下执行脚本（保证 `$(pwd)/mnt` 正确）。
- 容器挂载入口固定为宿主机路径 `$(pwd)/mnt`，即 `cuda11_8_ROS/mnt`。
- `cuda11_8_ROS/mnt` 应是一个指向宿主机真实工作目录的软链接。
- 容器内 `/workspace` 最终可见内容由 `mnt` 的软链接目标决定。

调整可见范围时，优先修改 `mnt` 的目标指向（例如切换到更大或更小的宿主目录），而不是改容器内路径。

创建或更新 `mnt` 软链接示例：
```bash
cd cuda11_8_ROS
ln -sfn /path/to/your/workspace mnt
```
示例中 `ln -sfn` 会将 `mnt` 指向新的宿主目录目标，便于切换容器内 `/workspace` 的可见范围。

示例检查命令：
```bash
cd cuda11_8_ROS
ls -l mnt
readlink mnt
```
如果软链接目标不存在或无权限，容器内 `/workspace` 可能为空或不可用；若切换目标后容器内未及时反映，以重启或重建容器实例作为兜底。

### 4) 远程 X11 额外说明
如果你在远程 `ssh -X` 场景运行，按脚本注释可额外挂载：
```bash
-v $HOME/.Xauthority:/root/.Xauthority
-v $HOME/.Xauthority:/home/ros/.Xauthority
```
用于处理 X11 鉴权问题。
