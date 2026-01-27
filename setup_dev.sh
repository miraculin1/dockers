#!/bin/bash
set -e

apt-get update \
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

apt-get update \
  && apt-get install -y \
  libsdl-image1.2-dev \
  libsdl1.2-dev \
  build-essential \
  && rm -rf /var/lib/apt/lists/*

ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

#### ROS ####
# echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list
# curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | apt-key add -
# apt-get update
# apt-get install -y ros-noetic-desktop-full \
          # || (sleep 5 && apt-get install -y ros-noetic-desktop-full --fix-missing)
#

# Create bin directory and download Neovim
cd \
&& mkdir bin && cd bin \
&& wget https://github.com/neovim/neovim/releases/download/v0.9.5/nvim-linux64.tar.gz \
&& tar -xf nvim-linux64.tar.gz \
&& ln -s nvim-linux64/bin/nvim nvim

# Clone the dotfiles repository
cd \
&& git clone https://github.com/miraculin1/dotfiles.git \
&& cd dotfiles \
&& curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
            https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

# Remove .bashrc, use stow to symlink configuration files
cd \
&& rm .bashrc \
&& cd dotfiles \
&& stow nvim \
&& stow bash \
&& stow tmux

cd \
  && curl -fsSL https://pyenv.run | bash \
  && export PYENV_ROOT="$HOME/.pyenv" \
  && export PATH="$PYENV_ROOT/bin:$PATH" \
  && pyenv install 3.11.9

# Update .bashrc with new PATH and ROS setup
cd \
  && echo PATH="$HOME/bin:$PATH" >> ~/.bashrc \
  && echo source /opt/ros/noetic/setup.bash >> ~/.bashrc \
  && echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc \
  && echo '[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc \
  && echo 'eval "$(pyenv init - bash)"' >> ~/.bashrc \
  && echo "alias vim='PYENV_VERSION=3.11.9 pyenv exec nvim'" >> ~/.bashrc 
  && export PYENV_ROOT="$HOME/.pyenv" \
  && export PATH="$PYENV_ROOT/bin:$PATH" \
  && export PATH="$HOME/bin:$PATH" \


PYENV_VERSION=3.11.9 pyenv exec nvim +PlugInstall +qall
