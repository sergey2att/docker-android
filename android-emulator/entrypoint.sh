#!/usr/bin/env bash

set -ex

./adb_redirect.sh
./run_emulator.sh "$SDK_VERSION" "$EMULATOR_ARCH"
