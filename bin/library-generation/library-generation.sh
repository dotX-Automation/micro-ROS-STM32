#!/bin/bash
set -e

# Controlla se il numero di argomenti è corretto
if [ "$#" -ne 1 ]; then
    echo "Uso: $0 <directory>"
    exit 1
fi

#sudo rosdep init
#rosdep update 
#sudo apt update

export BASE_PATH=/$1/$MICROROS_LIBRARY_FOLDER
#export BASE_PATH=$1

######## Init ########

source /opt/ros/$ROS_DISTRO/setup.bash
source install/local_setup.bash

ros2 run micro_ros_setup create_firmware_ws.sh generate_lib

######## Adding extra packages ########
pushd firmware/mcu_ws > /dev/null

    # Import user defined packages
    mkdir extra_packages
    pushd extra_packages > /dev/null
    	USER_CUSTOM_PACKAGES_DIR=../../../config/extra_packages 
    	if [ -d "$USER_CUSTOM_PACKAGES_DIR" ]; then
    		cp -R $USER_CUSTOM_PACKAGES_DIR/* .
		fi
        if [ -f $USER_CUSTOM_PACKAGES_DIR/extra_packages.repos ]; then
        	vcs import --input $USER_CUSTOM_PACKAGES_DIR/extra_packages.repos
        fi
        cp -R ../../../config/extra_packages/* .
        vcs import --input extra_packages.repos
    popd > /dev/null

popd > /dev/null

######## Trying to retrieve CFLAGS ########
pushd $1 > /dev/null
export RET_CFLAGS=$(make print_cflags)
RET_CODE=$?

if [ $RET_CODE = "0" ]; then
    echo "Found CFLAGS:"
    echo "-------------"
    echo $RET_CFLAGS
    echo "-------------"
    read -p "Do you want to continue with them? (y/n)" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
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

######## Build  ########
export TOOLCHAIN_PREFIX=arm-none-eabi-
ros2 run micro_ros_setup build_firmware.sh /home/neo/workspace/bin/library-generation/toolchain.cmake /home/neo/workspace/bin/library-generation/colcon.meta

find firmware/build/include/ -name "*.c"  -delete
rm -rf $BASE_PATH/libmicroros
mkdir -p $BASE_PATH/libmicroros/microros_include
cp -R firmware/build/include/* $BASE_PATH/libmicroros/microros_include/
cp -R firmware/build/libmicroros.a $BASE_PATH/libmicroros/libmicroros.a

######## Fix include paths  ########
pushd firmware/mcu_ws > /dev/null
    INCLUDE_ROS2_PACKAGES=$(colcon list | awk '{print $1}' | awk -v d=" " '{s=(NR==1?s:s d)$0}END{print s}')
popd > /dev/null

for var in ${INCLUDE_ROS2_PACKAGES}; do
    if [ -d "$BASE_PATH/libmicroros/microros_include/${var}/${var}" ]; then
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
