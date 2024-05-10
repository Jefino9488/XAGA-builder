#!/bin/bash

# Define colors
colors=(
    "\033[1;31m" # red
    "\033[1;33m" # yellow
    "\033[1;34m" # blue
    "\033[1;32m" # green
    "\033[0m"   # reset
)

# Set timezone, remove packages and install required tools
sudo timedatectl set-timezone Asia/Shanghai
sudo apt-get remove -y firefox zstd
sudo apt-get install -y python3 aria2

# Parse input arguments
if [ "$#" -ne 4 ]; then
    echo -e "${colors[0]}Error: Invalid number of arguments. Expected 4, received ${#}.${colors[5]}"
    exit 1
fi

url="$1"
vendor_url="$2"
github_env="$3"
github_workspace="$4"

# Validate URLs
if [[ ! "$url" =~ ^https?:// ]]; then
    echo -e "${colors[0]}Error: Invalid URL format for 'url'.${colors[5]}"
    exit 1
fi

if [[ ! "$vendor_url" =~ ^https?:// ]]; then
    echo -e "${colors[0]}Error: Invalid URL format for 'vendor_url'.${colors[5]}"
    exit 1
fi

echo -e "URL: ${colors[3]}$url${colors[5]}"
echo -e "Vendor URL: ${colors[3]}$vendor_url${colors[5]}"
echo -e "GitHub Environment: ${colors[3]}$github_env${colors[5]}"
echo -e "GitHub Workspace: ${colors[3]}$github_workspace${colors[5]}"
