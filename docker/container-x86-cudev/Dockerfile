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
# Set up colcon mixin and metadata
RUN colcon mixin add default https://raw.githubusercontent.com/colcon/colcon-mixin-repository/master/index.yaml && \
  colcon mixin update && \
  colcon metadata add default https://raw.githubusercontent.com/colcon/colcon-metadata-repository/master/index.yaml && \
  colcon metadata update

# Install GCC toolchain for STM32
WORKDIR /opt
RUN apt-get update && apt-get install -y --no-install-recommends \
  zstd && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*/apt/lists/* && \
  wget --no-check-certificate -O /tmp/gcc-arm-none-eabi-10.3-2021.10-x86_64-linux.tar.bz2 https://developer.arm.com/-/media/Files/downloads/gnu-rm/10.3-2021.10/gcc-arm-none-eabi-10.3-2021.10-x86_64-linux.tar.bz2 && \
  tar -jxf /tmp/gcc-arm-none-eabi-10.3-2021.10-x86_64-linux.tar.bz2 -C /opt/ && \
  rm -rf /tmp/gcc-arm-none-eabi-10.3-2021.10-x86_64-linux.tar.bz2 && \
  chgrp -R internal gcc-arm-none-eabi-10.3-2021.10 && \
  chmod -R g+rw gcc-arm-none-eabi-10.3-2021.10
ENV PATH=/opt/gcc-arm-none-eabi-10.3-2021.10/bin:${PATH}
WORKDIR /root

# Install micro-ros-setup dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
  clang-format \
  clang-tidy \
  gperf \
  pyflakes3 \
  python3-babeltrace \
  python3-lttng \
  python3-mypy \
  python3-nose \
  python3-pytest-mock \
  ros-humble-mimick-vendor \
  ros-humble-osrf-testing-tools-cpp && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*/apt/lists/*

# Initialize apt and rosdep
RUN . /opt/ros/humble/setup.sh && \
  apt-get update && \
  rosdep init && \
  rosdep update
  
# Install stm32 cube ide and cube mx
WORKDIR /opt
RUN wget -U "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0" -O stm32cubemx.zip "https://www.st.com/content/ccc/resource/technical/software/sw_development_suite/group1/6c/0c/a3/4c/ed/09/48/21/stm32cubemx-lin-v6-12-0/files/stm32cubemx-lin-v6-12-0.zip/jcr:content/translations/en.stm32cubemx-lin-v6-12-0.zip"
RUN unzip stm32cubemx.zip && \
    rm stm32cubemx.zip
RUN chmod +x SetupSTM32CubeMX-6.12.0

RUN wget -U "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0" -O stm32cubeide.zip "https://www.st.com/content/ccc/resource/technical/software/sw_development_suite/group1/f0/75/4c/32/97/a0/4d/48/stm32cubeide-deb/files/st-stm32cubeide_1.16.0_21983_20240628_1741_amd64.deb_bundle.sh.zip/jcr:content/translations/en.st-stm32cubeide_1.16.0_21983_20240628_1741_amd64.deb_bundle.sh.zip"
RUN unzip stm32cubeide.zip && \
    rm stm32cubeide.zip
RUN chmod +x st-stm32cubeide_1.16.0_21983_20240628_1741_amd64.deb_bundle.sh && \
    ./st-stm32cubeide_1.16.0_21983_20240628_1741_amd64.deb_bundle.sh 
WORKDIR /root
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
