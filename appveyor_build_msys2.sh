#!/usr/bin/env bash

# Exit early if any command fails
set -e

PKG_PREFIX="mingw-w64-$MSYS2_ARCH"

echo `pwd`

# bash configure
${TCL_TCLSH} tcl-conf
make
make install

ls *tkdnd*
