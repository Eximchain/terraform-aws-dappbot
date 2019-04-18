#!/bin/bash
set -eu -o pipefail

sudo apt-get update
sudo apt-get install -y build-essential npm unzip
# Add repository for current version of node
curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
sudo apt-get install -y nodejs