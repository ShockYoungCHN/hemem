#!/bin/bash
set -e

# build_install_kernel.sh
# 自动化编译并安装 HeMem 自定义 Linux 内核。
# 警告：此操作会修改系统引导配置。建议在虚拟机或非生产环境测试。

KERNEL_DIR="linux"
THREADS=32

# 0. Install Prerequisites (Optional, same as build_hemem.sh)
if [[ "$1" == "--install-deps" ]]; then
    ./install_deps.sh
fi

# Force use of GCC 8 for kernel build
export CC=gcc-8
export CXX=g++-8
# Kernel build system often uses HOSTCC for host tools
export HOSTCC=gcc-8
export HOSTCXX=g++-8

if [ ! -d "$KERNEL_DIR" ]; then
    echo ">>> 错误：未找到 '$KERNEL_DIR' 目录。请确保在 HeMem 根目录下运行此脚本。"
    exit 1
fi

echo ">>> 开始处理内核..."
cd "$KERNEL_DIR"

# 1. 配置内核
# 如果没有 .config 文件，使用当前系统的配置作为基础
if [ ! -f .config ]; then
    echo ">>> 未找到 .config，正在复制当前系统配置..."
    if [ -f "/boot/config-$(uname -r)" ]; then
        cp "/boot/config-$(uname -r)" .config
    else
        echo ">>> 警告：无法找到当前系统配置，使用 defconfig (可能缺少必要驱动)。"
        make defconfig
    fi
    
    # 自动更新配置以适应新内核版本（一路回车接受默认值）
    echo ">>> 更新内核配置 (olddefconfig)..."
    make olddefconfig

    # 清除证书配置以避免报错
    echo ">>> 清除证书配置以避免报错..."
    ./scripts/config --set-str SYSTEM_TRUSTED_KEYS ""
    ./scripts/config --set-str SYSTEM_REVOCATION_KEYS ""

    # 禁用调试信息以节省空间
    echo ">>> 禁用调试信息 (CONFIG_DEBUG_INFO) 以节省空间..."
    ./scripts/config --disable DEBUG_INFO
    ./scripts/config --disable DEBUG_INFO_SPLIT
    ./scripts/config --disable DEBUG_INFO_DWARF4
    ./scripts/config --disable DEBUG_INFO_BTF

    make olddefconfig
fi

# 2. 编译内核
echo ">>> 开始编译内核 (使用 $THREADS 线程)... 这可能需要很长时间..."
make -j"$THREADS"

# 3. 安装模块
echo ">>> 正在安装内核模块 (需要 sudo)..."
sudo make modules_install

# 4. 安装内核
echo ">>> 正在安装内核镜像 (需要 sudo)..."
sudo make install

echo ">>> 内核编译与安装完成。"
echo ">>> 请检查 /boot/grub/grub.cfg 或使用 update-grub 确认新内核已被识别。"
echo ">>> 你可能需要重启系统并在 GRUB 菜单中选择新安装的内核。"
echo ">>> 内核版本通常可以在 include/generated/uapi/linux/version.h 或 Makefile 中查看。"

cd ..
