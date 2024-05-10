#!/bin/bash

############################################
# Magisk General Utility Functions
############################################

###################
# Global Variables
###################

# True if the script is running on booted Android, not something like recovery
BOOTMODE=

# The path to store temporary files that don't need to persist
TMPDIR=/dev/tmp

# The path to store files that can be persisted (non-volatile storage)
NVBASE=

# The non-volatile path where magisk executables are stored
MAGISKBIN=

###################
# Helper Functions
###################

ui_print() {
  if $BOOTMODE; then
    echo "$1"
  else
    echo -e "ui_print $1\nui_print" >> /proc/self/fd/$OUTFD
  fi
}

toupper() {
  echo "$@" | tr '[:lower:]' '[:upper:]'
}

grep_cmdline() {
  local REGEX="s/^$1=//p"
  if [ -n "$2" ]; then
    echo $(cat /proc/cmdline)$(sed -e 's/[^"]//g' -e 's/""//g' /proc/cmdline) | xargs -n 1 | grep -E "$REGEX"
  else
    echo $(cat /proc/cmdline)$(sed -e 's/[^"]//g' -e 's/""//g' /proc/cmdline) | xargs -n 1 | grep -E "$REGEX" | head -n 1
  fi
}

grep_prop() {
  local REGEX="s/^$1=//p"
  shift
  local FILES=$@
  [ -z "$FILES" ] && FILES='/system/build.prop'
  if [ -n "$FILES" ]; then
    cat $FILES 2>/dev/null | dos2unix | sed -n "$REGEX" | head -n 1
  fi
}

grep_get_prop() {
  local result=$(grep_prop $@)
  if [ -n "$result
