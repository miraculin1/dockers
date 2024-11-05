FROM ubuntu:20.04

RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

RUN apt-get update \
  && apt-get install -y \
  ca-certificates

RUN cp /etc/apt/sources.list /etc/apt/sources.list.backup \
  && echo "# 默认注释了源码仓库，如有需要可自行取消注释 \
deb https://mirrors.ustc.edu.cn/ubuntu/ focal main restricted universe multiverse \
# deb-src https://mirrors.ustc.edu.cn/ubuntu/ focal main restricted universe multiverse \
 \
deb https://mirrors.ustc.edu.cn/ubuntu/ focal-security main restricted universe multiverse \
# deb-src https://mirrors.ustc.edu.cn/ubuntu/ focal-security main restricted universe multiverse \
 \
deb https://mirrors.ustc.edu.cn/ubuntu/ focal-updates main restricted universe multiverse \
# deb-src https://mirrors.ustc.edu.cn/ubuntu/ focal-updates main restricted universe multiverse \
 \
deb https://mirrors.ustc.edu.cn/ubuntu/ focal-backports main restricted universe multiverse \
# deb-src https://mirrors.ustc.edu.cn/ubuntu/ focal-backports main restricted universe multiverse \
 \
# 预发布软件源，不建议启用 \
# deb https://mirrors.ustc.edu.cn/ubuntu/ focal-proposed main restricted universe multiverse \
# deb-src https://mirrors.ustc.edu.cn/ubuntu/ focal-proposed main restricted universe multiverse" > /etc/apt/sources.list

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
  vim \
  curl \
  wget \
  libsdl-image1.2-dev \
  libsdl1.2-dev \
  python3.8-venv \
  build-essential \
  && rm -rf /var/lib/apt/lists/*


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

USER $USERNAME
RUN cd \
  && rm .bashrc \
  && cd dotfiles \
  && stow nvim \
  && stow bash \
  && cd \
  && echo PATH="$HOME/bin:$PATH" >> .bashrc \
  && export PATH="$HOME/bin:$PATH" \
  && nvim +PlugInstall +qall \
  && nvim +"MasonInstall cmake-language-server" +"MasonInstall clangd" +qall
