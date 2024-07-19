# DUA environment image.
#
# Roberto Masocco <r.masocco@dotxautomation.com>
#
# June 13, 2024

# Copyright 2024 dotX Automation s.r.l.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM dotxautomation/dua-foundation:x86-cudev

# Change this if you encounter problems with the default user
ARG USER_UID=1000

ENV DEBIAN_FRONTEND=noninteractive

# IMAGE SETUP START #
# micro-ROS-STM32 start #
RUN colcon mixin add default https://raw.githubusercontent.com/colcon/colcon-mixin-repository master/index.yaml && \
    colcon mixin update && \
    colcon metadata add default https://raw.githubusercontent.com/colcon/colcon-metadata-repository/master/index.yaml && \
    colcon metadata update

# Setup workspace and install additional tools
RUN apt update && \
    apt install -y wget dos2unix zstd && \
    rm -rf log/ build/ src/* && \
    rm -rf /var/lib/apt/lists/* && \
    wget --no-check-certificate https://developer.arm.com/-/media/Files/downloads/gnu-rm/10.3-2021.10/gcc-arm-none-eabi-10.3-2021.10-x86_64-linux.tar.bz2 && \
    tar -xvf gcc-arm-none-eabi-10.3-2021.10-x86_64-linux.tar.bz2 && \
    rm -rf gcc-arm-none-eabi-10.3-2021.10-x86_64-linux.tar.bz2 gcc-arm-none-eabi-10.3-2021.10/share/doc
    
# Clone micro-ROS and setup environment
RUN git clone -b $ROS_DISTRO https://github.com/micro-ROS/micro-ros-build.git src/micro-ros-build && \
    . /opt/ros/$ROS_DISTRO/setup.sh && \
    apt update && \
    apt install -y rsync python3-pip python3-nose clang-format pyflakes3 python3-mypy python3-pytest-mock gperf ros-$ROS_DISTRO-osrf-testing-tools-cpp python3-lttng ros-$ROS_DISTRO-mimick-vendor python3-babeltrace && \
    rosdep update --rosdistro $ROS_DISTRO && \
    rosdep install --from-paths src --ignore-src -y && \
    colcon build && \
    . install/local_setup.sh && \
    rm -rf log/ build/ src/* && \
    rm -rf /var/lib/apt/lists/*
# micro-ROS-STM32 end #
# IMAGE SETUP END #

# Create a user with Zsh as shell, hashed password, and add it to the sudoers
# To generate the hashed password, run:
#   mkpasswd -m sha-512 PASSWORD duatemplate
RUN useradd -r -m -s /usr/bin/zsh -u ${USER_UID} -G adm,dialout,internal,plugdev,sudo,tty,video -p '$6$duatemplate$QKfJCvQqdM7zLVZDlza5C5ByMDDcet0aWwFYL1BmsLJWTb4zAfbvsUEbnOpCS8p9XkC4E1v0k5gAh1k3wanpr.' neo
ENV HOME=/home/neo

# Create workspace directory: host workspaces will be mounted here
RUN mkdir ${HOME}/workspace && \
  chown neo:neo ${HOME}/workspace

# Create directory for shell history file
RUN mkdir ${HOME}/zsh_history && \
  chown neo:neo ${HOME}/zsh_history

# Create SSH directory for user
RUN mkdir ${HOME}/.ssh

# Switch to internal user
USER neo
WORKDIR ${HOME}

# Copy user configuration files
COPY --chown=neo:neo ./aliases.sh ./.aliases.sh
COPY --chown=neo:neo ./bashrc ./.bashrc
COPY --chown=neo:neo ./colcon-defaults.yaml /home/neo/.colcon/defaults.yaml
COPY --chown=neo:neo ./commands.sh ./.commands.sh
COPY --chown=neo:neo ./nanorc ./.nanorc
COPY --chown=neo:neo ./ros2.sh ./.ros2.sh
COPY --chown=neo:neo ./vimrc ./.vimrc

# Configure Zsh for internal user
ENV ZSH=${HOME}/.oh-my-zsh
ENV ZSH_CUSTOM=${ZSH}/custom
ENV ZSH_PLUGINS=${ZSH_CUSTOM}/plugins
ENV ZSH_THEMES=${ZSH_CUSTOM}/themes
RUN wget -qO- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | zsh || true
RUN git clone --single-branch --branch 'master' --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_PLUGINS}/zsh-syntax-highlighting \
  && git clone --single-branch --branch 'master' --depth 1 https://github.com/zsh-users/zsh-autosuggestions ${ZSH_PLUGINS}/zsh-autosuggestions \
  && git clone --single-branch --depth 1 https://github.com/romkatv/powerlevel10k.git ${ZSH_THEMES}/powerlevel10k
COPY --chown=neo:neo ./p10k.zsh ./.p10k.zsh
COPY --chown=neo:neo ./zshrc ./.zshrc

ENV DEBIAN_FRONTEND=dialog

# By default, start a basic shell
CMD ["bash"]
