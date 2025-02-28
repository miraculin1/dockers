FROM nvidia/cuda:12.1.0-cudnn8-devel-ubuntu20.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai

RUN apt-get update \
  && apt-get install -y \
  ca-certificates

RUN cp /etc/apt/sources.list /etc/apt/sources.list.backup

RUN echo "# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释\n\
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal main restricted universe multiverse\n\
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal main restricted universe multiverse\n\
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-updates main restricted universe multiverse\n\
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-updates main restricted universe multiverse\n\
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-backports main restricted universe multiverse\n\
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-backports main restricted universe multiverse\n\
\n\
# 以下安全更新软件源包含了官方源与镜像站配置，如有需要可自行修改注释切换\n\
deb http://security.ubuntu.com/ubuntu/ focal-security main restricted universe multiverse\n\
# deb-src http://security.ubuntu.com/ubuntu/ focal-security main restricted universe multiverse\n\
" > /etc/apt/sources.list

RUN apt-get update \
  && apt-get install -y \
  vim \
  curl \
  wget \
  ripgrep \
  tmux \
  unzip \
  ranger \
  software-properties-common \
  tar \
  stow \
  git \
  wget \
  ffmpeg \
  libsm6 \
  libxext6 \
  sudo \
  gcc \
  locales \
  bash-completion \
  tzdata \
  python3-venv

RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

RUN cd \
  && git clone https://github.com/miraculin1/dotfiles.git \
  && cd dotfiles \
  && curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
       https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

RUN cd \
  && mkdir bin && cd bin \
  && wget https://github.com/neovim/neovim/releases/download/v0.9.5/nvim-linux64.tar.gz \
  && tar -xf nvim-linux64.tar.gz \
  && ln -s nvim-linux64/bin/nvim nvim

RUN cd \
  && mkdir ~/.config/ -p\
  && mv .bashrc .bashrc.backup\
  && cd dotfiles \
  && stow nvim \
  && stow bash \
  && stow tmux \
  && cd \
  && echo PATH="$HOME/bin:$PATH" >> .bashrc \
  && export PATH="$HOME/bin:$PATH" \
  && nvim +PlugInstall +qall

RUN cd \
  && curl -O https://repo.anaconda.com/archive/Anaconda3-2024.10-1-Linux-x86_64.sh

RUN cd \
  && bash Anaconda3-2024.10-1-Linux-x86_64.sh -b -p /opt/anaconda3 \
  && rm Anaconda3-2024.10-1-Linux-x86_64.sh

RUN apt-get update \
  && apt-get install -y \
  libsdl-image1.2-dev \
  libsdl1.2-dev \
  build-essential \
  && rm -rf /var/lib/apt/lists/*

RUN echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list
RUN curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | apt-key add -
RUN apt-get update
RUN apt-get install -y ros-noetic-desktop-full \
  || (sleep 5 && apt-get install -y ros-noetic-desktop-full --fix-missing)

ENV ROS_DISTRO=noetic

ARG USERNAME=ros
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
  && useradd -s /bin/bash --uid $USER_UID --gid $USER_GID -m $USERNAME \
  && mkdir /home/$USERNAME/.config -p && chown $USER_UID:$USER_GID /home/$USERNAME/.config

RUN echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
  &&chmod 0440 /etc/sudoers.d/$USERNAME

USER $USERNAME
RUN cd \
  && mkdir bin && cd bin \
  && wget https://github.com/neovim/neovim/releases/download/v0.9.5/nvim-linux64.tar.gz \
  && tar -xf nvim-linux64.tar.gz \
  && ln -s nvim-linux64/bin/nvim nvim

USER $USERNAME
RUN cd \
  && git clone https://github.com/miraculin1/dotfiles.git \
  && cd dotfiles \
  && curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
       https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

USER $USERNAME
RUN cd \
  && rm .bashrc \
  && cd dotfiles \
  && stow nvim \
  && stow bash \
  && stow tmux \
  && cd \
  && echo PATH="$HOME/bin:$PATH" >> .bashrc \
  && echo source /opt/ros/noetic/setup.bash >> .bashrc \
  && export PATH="$HOME/bin:$PATH" \
  && nvim +PlugInstall +qall \
  && nvim +"MasonInstall cmake-language-server" +"MasonInstall clangd" +qall

USER root

RUN echo '#!/bin/bash\n\
set -e\n\
\n\
# setup ros environment\n\
source "/opt/anaconda3/bin/activate" \n\
source "/opt/ros/$ROS_DISTRO/setup.bash" --\n\
exec "$@"' > /ros_entrypoint.sh \
&& chmod +x /ros_entrypoint.sh

RUN chown $USER_UID:$USER_GID /ros_entrypoint.sh

ENTRYPOINT ["/ros_entrypoint.sh"]

USER $USERNAME
ENTRYPOINT ["/ros_entrypoint.sh"]

USER root

RUN apt-get clean \
  && rm -rf /var/lib/apt/lists/*

USER root
