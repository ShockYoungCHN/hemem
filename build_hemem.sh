#!/bin/bash
set -e

# HeMem Build Script
# Automates the build process for HeMem and its dependencies.

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
    echo ">>> Building Hoard..."
    cd Hoard
    # Force GCC as clang failed
    export CC=gcc
    export CXX=g++
    
    cd src
    # Clean previous attempt
    make clean || true
    # Explicitly call the linux gcc target with g++
    make Linux-gcc-x86_64 CXX=g++
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