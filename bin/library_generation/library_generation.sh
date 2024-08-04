#!/usr/bin/env bash

# micro-ROS static, Cube-compatible library generation script.
#
# August 4, 2024

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

# shellcheck disable=SC2207,SC2016,SC2086

set -o errexit
set -o nounset
set -o pipefail
if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi

function usage {
  echo >&2 "Usage:"
  echo >&2 "  library_generation.sh BOARD_DIRECTORY"
  echo >&2 "  BOARD_DIRECTORY: The directory containing the board-specific firmware code, omitting tools/ (e.g., \"F4/F429ZI\")"
}

# Check input arguments
if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

# Check that current working directory is 'workspace'
if [[ "$(pwd)" != "/home/neo/workspace" ]]; then
  echo "ERROR: Please run this script from the workspace directory"
  exit 1
fi

# Setup environment
export MICROROS_LIBRARY_FOLDER=micro_ros_stm32cubemx_utils/microros_static_library
export BASE_PATH=$MICROROS_LIBRARY_FOLDER
unset RMW_IMPLEMENTATION

# Setup ROS installation
# NOTE: No need to source it since it is already sourced by default in DUA container shells.
rosdep update

# Create firmware workspace
# NOTE: This creates a 'firmware' directory containing code for both development and microcontroller
# firmware. The 'mcu_ws' directory contains the microcontroller firmware code, while the 'dev_ws'
# directory may contain additional ROS2 packages required for development.
# This is achieved by calling the 'create_firmware_ws.sh' script with the 'generate_lib' argument,
# which identifies the generic, platform-agnostic, static library target.
if [[ -d "tools/firmware" ]]; then
  rm -rf "tools/firmware"
fi
cd tools
ros2 run micro_ros_setup create_firmware_ws.sh generate_lib

# Add extra packages
# NOTE: This step depends on what you have to do with this firmare.
# If you need to add more packages, you can modify the file(s) in config/extra_packages.
pushd firmware/mcu_ws > /dev/null
  # Import user defined packages
  mkdir extra_packages
  pushd extra_packages > /dev/null
  	USER_CUSTOM_PACKAGES_DIR="../../../../config/extra_packages"
  	if [[ -d "$USER_CUSTOM_PACKAGES_DIR" ]]; then
  		cp -R $USER_CUSTOM_PACKAGES_DIR/* .
    fi
    if [[ -f "$USER_CUSTOM_PACKAGES_DIR/extra_packages.repos" ]]; then
    	vcs import --input "$USER_CUSTOM_PACKAGES_DIR/extra_packages.repos"
    fi
  popd > /dev/null
popd > /dev/null

# Try to retrieve CFLAGS from Makefile
pushd "$1" > /dev/null
  ret_cflags=$(make print_cflags)
  RET_CODE=$?
  export RET_CFLAGS=$ret_cflags

  if [[ $RET_CODE -eq 0 ]]; then
    echo "Found CFLAGS:"
    echo "-------------"
    echo "$RET_CFLAGS"
    echo "-------------"
    read -p "Do you want to continue with them? (y/n)" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      echo "Continuing..."
    else
      echo "Aborting"
      exit 0;
    fi
  else
    echo "Please read README.md to update your Makefile"
    exit 1;
  fi
popd > /dev/null

# Build library
# NOTE: Here we must supply toolchain commands and compile definition for cross-compilation.
export TOOLCHAIN_PREFIX=arm-none-eabi-
ros2 run micro_ros_setup build_firmware.sh /home/neo/workspace/bin/library_generation/toolchain.cmake /home/neo/workspace/bin/library_generation/colcon.meta

find firmware/build/include/ -name "*.c" -delete
rm -rf $BASE_PATH/libmicroros || true
mkdir -p $BASE_PATH/libmicroros/microros_include
cp -R firmware/build/include/* $BASE_PATH/libmicroros/microros_include/
cp -R firmware/build/libmicroros.a $BASE_PATH/libmicroros/libmicroros.a

# Fix include paths
pushd firmware/mcu_ws > /dev/null
  INCLUDE_ROS2_PACKAGES=$(colcon list | awk '{print $1}' | awk -v d=" " '{s=(NR==1?s:s d)$0}END{print s}')
popd > /dev/null

for var in ${INCLUDE_ROS2_PACKAGES}; do
  if [[ -d "$BASE_PATH/libmicroros/microros_include/${var}/${var}" ]]; then
    rsync -r $BASE_PATH/libmicroros/microros_include/${var}/${var}/* $BASE_PATH/libmicroros/microros_include/${var}
    rm -rf $BASE_PATH/libmicroros/microros_include/${var}/${var}
  fi
done

######## Generate extra files ########
find firmware/mcu_ws/ros2 \( -name "*.srv" -o -name "*.msg" -o -name "*.action" \) | awk -F"/" '{print $(NF-2)"/"$NF}' > $BASE_PATH/libmicroros/available_ros2_types
find firmware/mcu_ws/extra_packages \( -name "*.srv" -o -name "*.msg" -o -name "*.action" \) | awk -F"/" '{print $(NF-2)"/"$NF}' >> $BASE_PATH/libmicroros/available_ros2_types

cd firmware
echo "" > $BASE_PATH/libmicroros/built_packages
for f in $(find $(pwd) -name .git -type d); do pushd $f > /dev/null; echo $(git config --get remote.origin.url) $(git rev-parse HEAD) >> $BASE_PATH/libmicroros/built_packages; popd > /dev/null; done;

######## Fix permissions ########
sudo chmod -R 777 $BASE_PATH/libmicroros/
sudo chmod -R 777 $BASE_PATH/libmicroros/microros_include/
sudo chmod -R 777 $BASE_PATH/libmicroros/libmicroros.a
