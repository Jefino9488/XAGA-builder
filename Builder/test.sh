#!/bin/bash

# Define colors
red='\033[1;31m'
yellow='\033[1;33m'
blue='\033[1;34m'
green='\033[1;32m'
reset='\033[0m'

# Set timezone, remove packages and install required tools
sudo timedatectl set-timezone Asia/Shanghai
sudo apt-get remove -y firefox zstd
sudo apt-get install -y python3 aria2

# Parse input arguments
url="$1"
vendor_url="$2"
github_env="$3"
github_workspace="$4"

