 # NOTE: this script doesn't work, due to anaconda failed to install withou root, USE install.sh
FROM nvidia/cuda:12.1.0-cudnn8-devel-ubuntu22.04
ARG USERNAME=cuda
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
  && useradd -s /bin/bash --uid $USER_UID --gid $USER_GID -m $USERNAME \
  && mkdir /home/$USERNAME/.config && chown $USER_UID:$USER_GID /home/$USERNAME/.config

RUN mkdir /etc/sudoers.d -p \
  &&echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
  &&chmod 0440 /etc/sudoers.d/$USERNAME

RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

RUN apt-get update \
  && apt-get install -y \
  ca-certificates

RUN cp /etc/apt/sources.list /etc/apt/sources.list.backup
RUN echo "# 默认注释了源码仓库，如有需要可自行取消注释\ndeb https://mirrors.ustc.edu.cn/ubuntu/ jammy main restricted universe multiverse\n# deb-src https://mirrors.ustc.edu.cn/ubuntu/ jammy main restricted universe multiverse\ndeb https://mirrors.ustc.edu.cn/ubuntu/ jammy-security main restricted universe multiverse\n# deb-src https://mirrors.ustc.edu.cn/ubuntu/ jammy-security main restricted universe multiverse\ndeb https://mirrors.ustc.edu.cn/ubuntu/ jammy-updates main restricted universe multiverse\n# deb-src https://mirrors.ustc.edu.cn/ubuntu/ jammy-updates main restricted universe multiverse\ndeb https://mirrors.ustc.edu.cn/ubuntu/ jammy-backports main restricted universe multiverse\n# deb-src https://mirrors.ustc.edu.cn/ubuntu/ jammy-backports main restricted universe multiverse\n# 预发布软件源，不建议启用\n# deb https://mirrors.ustc.edu.cn/ubuntu/ jammy-proposed main restricted universe multiverse\n# deb-src https://mirrors.ustc.edu.cn/ubuntu/ jammy-proposed main restricted universe multiverse" > /etc/apt/sources.list

RUN apt update \
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
  python3.10-venv

RUN cd \
  && wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-keyring_1.1-1_all.deb \
  && dpkg -i cuda-keyring_1.1-1_all.deb \
  && apt-get update


USER $USERNAME
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
  && mv .bashrc .bashrc.backup\
  && cd dotfiles \
  && stow nvim \
  && stow bash \
  && stow tmux \
  && cd \
  && echo PATH="$HOME/bin:$PATH" >> .bashrc \
  && export PATH="$HOME/bin:$PATH" \
  && nvim +PlugInstall +qall \
  && nvim +"MasonInstall cmake-language-server" +"MasonInstall clangd" +qall

RUN cd \
  && curl -O https://repo.anaconda.com/archive/Anaconda3-2024.10-1-Linux-x86_64.sh
