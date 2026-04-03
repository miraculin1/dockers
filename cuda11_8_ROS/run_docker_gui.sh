#! bin/bash
  #
# install docker
# install nvidia_container_toolkti
# modify /etc/nvidia-container-runtime/config.toml line with "user"
# to grant permmision
# in docker file, set the max file descibe count with ulimit
#  --rm \
#
# NOTE: if run on remote ssh -X session, add:
#  -v $HOME/.Xauthority:/root/.Xauthority \
#  -v $HOME/.Xauthority:/home/ros/.Xauthority \
# to get through X11 auth, more test is needed
export DRIVER_VERSION=$(cat /proc/driver/nvidia/version | grep -oP 'Kernel Module\s+\K[0-9.]+')

docker run -it \
  --gpus all \
  --name $1 \
  --user ros \
  --device=/dev/dri:/dev/dri \
  --network=host --ipc=host \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -e DISPLAY=$DISPLAY \
  --env="QT_X11_NO_MITSHM=1" \
  -v /usr/lib/x86_64-linux-gnu/libnvidia-glcore.so.${DRIVER_VERSION}:/usr/lib/x86_64-linux-gnu/libnvidia-glcore.so.0 \
  -v /usr/lib/x86_64-linux-gnu/libnvidia-tls.so.${DRIVER_VERSION}:/usr/lib/x86_64-linux-gnu/libnvidia-tls.so.0 \
  -v /usr/lib/x86_64-linux-gnu/libnvidia-glsi.so.${DRIVER_VERSION}:/usr/lib/x86_64-linux-gnu/libnvidia-glsi.so.0 \
  -v /usr/lib/x86_64-linux-gnu/libnvidia-gpucomp.so.${DRIVER_VERSION}:/usr/lib/x86_64-linux-gnu/libnvidia-gpucomp.so.0 \
  -e LIBGL_ALWAYS_INDIRECT=0 \
  --env="NVIDIA_DRIVER_CAPABILITIES=all" \
  --env="NVIDIA_VISIBLE_DEVICES=all" \
  --device /dev:/dev \
  -v /dev:/dev \
  --privileged \
  -v $(pwd)/mnt:/workspace \
  --ulimit nofile=1024:524288 \
  -e "TERM=xterm-256color" \
  cuda11_8_ros:latest bash

