#! bin/bash
  #
# install docker
# install nvidia_container_toolkti
# modify /etc/nvidia-container-runtime/config.toml line with "user"
# to grant permmision
# in docker file, set the max file descibe count with ulimit
#  --rm \

docker run -it \
  --gpus all \
  --name $1 \
  --user ros \
  --device=/dev/dri:/dev/dri \
  --network=host --ipc=host \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -e DISPLAY=$DISPLAY \
  --env="QT_X11_NO_MITSHM=1" \
  --env="NVIDIA_DRIVER_CAPABILITIERS=all" \
  --env="NVIDIA_VISABLE_DEVICES=all" \
  --device /dev:/dev \
  -v /dev:/dev \
  --privileged \
  -v $(pwd)/mnt:/workspace \
  --ulimit nofile=1024:524288 \
  -e "TERM=xterm-256color" \
  cuda11.3_ros:latest bash

