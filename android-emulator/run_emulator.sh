#!/usr/bin/env bash

# Script for running emulator using default `emulator` tool

ANDROID_AVD_HOME=/root/.android/avd

is_mounted () {
    mount | grep "$1"
}

initialize_data_part() {
  # Check if we have mounted a data partition (tmpfs, or persistent)
  # and if so, we will use that as our avd directory.
  if  is_mounted /data; then
    cp -fr /root/.android/avd/ /data
    ln -sf /data/root/.android/avd ${ANDROID_AVD_HOME}
    echo "path=${ANDROID_AVD_HOME}/emulator_${SDK_VERSION}.avd" > ${ANDROID_AVD_HOME}/emulator_${SDK_VERSION}.ini
  else
    ln -sf /root/.android/avd ${ANDROID_AVD_HOME}
  fi
}

forward_loggers() {
  mkdir /tmp/android-unknown
  mkfifo /tmp/android-unknown/kernel.log
  mkfifo /tmp/android-unknown/logcat.log
  echo "emulator: It is safe to ignore the warnings from tail. The files will come into existence soon."
  tail --retry -f /tmp/android-unknown/goldfish_rtc_0 | sed -u 's/^/video: /g' &
  cat /tmp/android-unknown/kernel.log | sed -u 's/^/kernel: /g' &
  cat /tmp/android-unknown/logcat.log | sed -u 's/^/logcat: /g' &
}

set -ex

forward_loggers
initialize_data_part

if [[ "$#" -ne 2 ]]; then
    echo "ERROR: Wrong number of arguments $#. Expected ones:
    SDK version, emulator architecture.

    For example:
    ./run_emulator.sh 24 x86
    "
    exit 1
fi

if ! [[ $1 =~ ^[0-9]+$ ]]; then
    echo_error "ERROR: Incorrect SDK version passed. An integer value expected, see https://developer.android.com/studio/releases/platforms"
    exit 1
fi

if ! [[ $2 =~ ^x86(_64)?$ ]]; then
    echo_error "ERROR: Incorrect emulator architecture passed. x86 and x86_64 are supported."
    exit 1
fi

readonly SDK_VERSION=$1
readonly EMULATOR_ARCH=$2

emulator_name="emulator_${SDK_VERSION}"
sd_card_name="/sdcard.img"

emulator_arguments=(-avd ${emulator_name} -sdcard ${sd_card_name} -verbose)

if [[ ${WINDOW} == "true" ]]; then
    binary_name="qemu-system-x86_64"

    if [[ -z "${DISPLAY}" ]]; then
        export DISPLAY=":0"
    fi

    echo "Rendering: Window swiftshader (software) rendering mode is enabled on ${DISPLAY} display (make sure, that you pass X11 socket)"
    emulator_arguments+=(-gpu swiftshader_indirect)
else
    binary_name="qemu-system-x86_64-headless"

    echo "Rendering: Headless swiftshader (software) rendering mode is enabled"
    emulator_arguments+=(-no-window -gpu swiftshader_indirect)
fi

emulator_arguments+=(-no-boot-anim -no-snapshot -no-audio -partition-size 2048 -shell-serial file:/tmp/android-unknown/kernel.log -qemu -append panic=1)

if [ ! -z "${EMULATOR_PARAMS}" ]; then
  emulator_arguments+=($EMULATOR_PARAMS)
fi

# emulator uses adb so we make sure that server is running
adb start-server

cd /opt/android-sdk/emulator
ls -la /opt/android-sdk/system-images/
echo "$ANDROID_SDK_ROOT"
echo "Run ${binary_name} binary for emulator ${emulator_name} with abi: $EMULATOR_ARCH (Version: ${SDK_VERSION})"
echo "no" | ./qemu/linux-x86_64/${binary_name} "${emulator_arguments[@]}"
