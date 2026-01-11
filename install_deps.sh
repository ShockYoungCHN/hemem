#!/bin/bash
set -e

# install_deps.sh
echo ">>> Installing prerequisites..."
sudo apt update
sudo apt install -y gcc-8 g++-8 ndctl build-essential libncurses-dev bison flex libssl-dev libelf-dev fakeroot dwarves libcapstone-dev pkg-config

echo ">>> Configuring gcc-8 as default..."
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-8 80 --slave /usr/bin/g++ g++ /usr/bin/g++-8

echo ">>> Prerequisites installed."
