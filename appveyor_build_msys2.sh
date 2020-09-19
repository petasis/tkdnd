#!/usr/bin/env bash

# Exit early if any command fails
set -e

PKG_PREFIX="mingw-w64-$MSYS2_ARCH"

bash configure
make
make install
