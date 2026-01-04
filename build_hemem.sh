#!/bin/bash
set -e

# HeMem Build Script
# Automates the build process for HeMem and its dependencies.
# Note: These instructions assume a dual-socket server (Intel Ice Lake architecture).
# Tested on Ubuntu 20.04.

# 0. Install Prerequisites (Requires sudo)
# Run with --install-deps to execute these commands
if [[ "$1" == "--install-deps" ]]; then
    echo ">>> Installing prerequisites..."
    sudo apt update
    sudo apt install -y gcc-8 g++-8 ndctl build-essential libncurses-dev bison flex libssl-dev libelf-dev fakeroot dwarves
    
    # Configure gcc-8 as an alternative
    sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-8 80 --slave /usr/bin/g++ g++ /usr/bin/g++-8
    echo ">>> Prerequisites installed. Using gcc-8 for the build."
    
    # Force use of gcc-8 for the rest of the script
    export CC=gcc-8
    export CXX=g++-8
fi

echo ">>> Initializing git submodules..."
git submodule update --init --recursive
echo ">>> Git submodules initialized."

# 1. Build Linux Kernel Headers (Required for HeMem compilation)
if [ -d "linux" ]; then
    echo ">>> 'linux/' directory detected. Installing kernel headers to linux/usr/include/..."
    # HeMem src/Makefile references ../linux/usr/include/
    # So we need to install headers locally.
    cd linux
    # Only install headers, building the full kernel takes too long and might not be needed just to compile HeMem userspace lib.
    # But if the user wants to run it, they need the kernel.
    # For now, let's ensure headers are present.
    make headers_install INSTALL_HDR_PATH=./usr
    cd ..
    echo ">>> Kernel headers installed."
else
    echo ">>> WARNING: 'linux/' directory not found. HeMem compilation might fail due to missing headers."
fi

# 2. Build Hoard
if [ -d "Hoard" ]; then
    echo ">>> Patching Hoard for compatibility..."
    # Fix GCC 13 inlining error in libhoard.cpp
    sed -i 's/void \* __attribute__((always_inline)) xxmalloc/inline void \* xxmalloc/g' Hoard/src/source/libhoard.cpp
    sed -i 's/void __attribute__((flatten)) __attribute__((always_inline)) xxfree/inline void __attribute__((flatten)) xxfree/g' Hoard/src/source/libhoard.cpp
    sed -i 's/void \* __attribute__((always_inline)) xxmemalign/inline void \* xxmemalign/g' Hoard/src/source/libhoard.cpp
    
    # Fix MyHashMap missing type error in alignedmmap.h
    # Wrap the problematic typedefs in #if TRACK_SIZE
    if ! grep -q "if TRACK_SIZE" Hoard/src/include/util/alignedmmap.h; then
        sed -i '/\/\/ Manage information in a map/,/typedef MyHashMap/ { /typedef MyHashMap/ s/$/\n#endif/; /Manage information/ s/^/#if TRACK_SIZE\n/ }' Hoard/src/include/util/alignedmmap.h
    fi

    echo ">>> Building Hoard..."
    cd Hoard
    # Force GCC as clang often fails with missing standard headers
    export CC=${CC:-gcc}
    export CXX=${CXX:-g++}
    
    cd src
    # Clean previous attempt
    make clean || true
    # Explicitly call the linux gcc target with CXX override
    make Linux-gcc-x86_64 CXX=$CXX
    cd ../..
    echo ">>> Hoard build complete."
else
    echo ">>> WARNING: 'Hoard/' directory not found."
fi

# 3. Build libsyscall_intercept
echo ">>> Checking libsyscall_intercept..."
if [ ! -d "libsyscall_intercept" ]; then
    echo ">>> libsyscall_intercept not found. Cloning..."
    git clone https://github.com/pmem/syscall_intercept.git libsyscall_intercept
fi

if [ -d "libsyscall_intercept" ]; then
    echo ">>> Building libsyscall_intercept..."
    cd libsyscall_intercept
    mkdir -p build
    cd build
    # Install to a local directory if sudo is not available
    cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$PWD/../install
    make -j$(nproc)
    make install
    
    # Capture absolute paths for use in HeMem build
    LIBSYSCALL_LIB="$PWD/../install/lib"
    LIBSYSCALL_LIB64="$PWD/../install/lib64"
    LIBSYSCALL_INC="$PWD/../install/include"
    
    cd ../..
    echo ">>> libsyscall_intercept build complete (installed in libsyscall_intercept/install)."
else
    echo ">>> ERROR: Could not get libsyscall_intercept."
    exit 1
fi

# 4. Build HeMem
if [ -d "src" ]; then
    echo ">>> Building HeMem (src/)..."
    cd src
    # Pass the paths for libsyscall_intercept explicitly
    # Note: linux headers are in ../linux/usr/include
    make -j$(nproc) INCLUDES="-I../linux/usr/include/ -I$LIBSYSCALL_INC" \
                    HEMEM_LIBS="-lm -lpthread -ldl -lsyscall_intercept -L../Hoard/src -lhoard -L$LIBSYSCALL_LIB -L$LIBSYSCALL_LIB64"
    cd ..
    echo ">>> HeMem build complete."
else
    echo ">>> ERROR: 'src/' directory not found."
fi

echo ">>> Script finished."