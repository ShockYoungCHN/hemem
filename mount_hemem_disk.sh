#!/bin/bash
set -e

# 配置
DISK="/dev/sdb"
PART_SIZE="100GB"
LINUX_DIR="linux"

# 检查是否在项目根目录
if [ ! -f "build_install_kernel.sh" ]; then
    echo "错误: 请在 hemem 项目根目录下运行此脚本。"
    exit 1
fi

echo ">>> [1/5] 检查并卸载旧挂载..."
if mountpoint -q "$LINUX_DIR"; then
    echo "    发现 $LINUX_DIR 已挂载，正在卸载..."
    sudo umount "$LINUX_DIR"
fi

echo ">>> [2/5] 清理 $LINUX_DIR 以释放根分区空间..."
rm -rf "$LINUX_DIR"
mkdir -p "$LINUX_DIR"

echo ">>> [3/5] 分区并格式化 $DISK ..."
echo "    警告：$DISK 上的数据将被清除！"
sudo parted -s $DISK mklabel gpt
sudo parted -s -a opt $DISK mkpart primary ext4 0% $PART_SIZE
sleep 2
PARTITION="${DISK}1"
sudo mkfs.ext4 -F -q $PARTITION

echo ">>> [4/5] 挂载 $PARTITION 到 $LINUX_DIR ..."
sudo mount $PARTITION "$LINUX_DIR"

echo ">>> [5/5] 修正目录权限..."
sudo chown -R $(id -u):$(id -g) "$LINUX_DIR"

echo ">>> 挂载完成！"
df -h "$LINUX_DIR"
