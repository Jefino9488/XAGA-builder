#!/bin/sh

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
  if [ "$BOOTMODE" = true ]; then
    echo -n "$1"
  else
    echo -ne "ui_print $1\nui_print" > /proc/self/fd/$OUTFD
  fi
}

toupper() {
  echo "$@" | tr '[:lower:]' '[:upper:]'
}

grep_cmdline() {
  local REGEX="$1"
  local FILE=/proc/cmdline
  [ -e "$FILE" ] || return 1
  if [ -n "$2" ]; then
    sed -nEz "s/^$REGEX//p" "$FILE" | xargs -r -d ''
  else
    sed -nEz "s/^$REGEX//p" "$FILE" | head -n 1 | xargs -r
  fi
}

grep_prop() {
  local REGEX="$1"
  shift
  local FILES="$@"
  [ -z "$FILES" ] && FILES='/system/build.prop'
  if [ -n "$FILES" ]; then
    for FILE in $FILES; do
      [ -e "$FILE" ] || continue
      dos2unix -q "$FILE" || return 1
      sed -nEz "s/^$REGEX//p" "$FILE" | xargs -r -d '' || return 1
    done
  fi
}

grep_get_prop() {
  local result=$(grep_prop -w -i -P "$@" /system/build.prop /vendor/build.prop)
  [ -n "$result" ] || return 1
  echo "$result" | sed -ne 's/^[^=]*=//p'
}

