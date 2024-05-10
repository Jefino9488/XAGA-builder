#!/bin/bash

#######################################################################################
# Magisk Boot Image Patcher
#######################################################################################
#
# Usage: boot_patch.sh <bootimage>
#
# The following environment variables can configure the installation:
# KEEPVERITY, KEEPFORCEENCRYPT, PATCHVBMETAFLAG, RECOVERYMODE, LEGACYSAR
#
#######################################################################################

# Pure bash dirname implementation
getdir() {
  case "$1" in
    */*)
      dir=${1%/*}
      if [ -z "$dir" ]; then
        echo "/"
      else
        echo "$dir"
      fi
    ;;
    *) echo "." ;;
  esac
}

ui_print() {
  echo "$1"
}

abort() {
  ui_print "$1"
  exit 1
}


