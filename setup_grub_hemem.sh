#!/bin/bash
set -e

# update_grub_memmap.sh
# 这个脚本用于修改 GRUB 配置以预留内存区域用于 HeMem。
# 警告：修改 GRUB 配置有风险，错误的操作可能导致系统无法启动。

GRUB_CONFIG="/etc/default/grub"
BACKUP_CONFIG="${GRUB_CONFIG}.bak.$(date +%Y%m%d%H%M%S)"

# 预定义的 memmap 参数，对应于 HeMem 示例中的设置：
# memmap=32G!130G (NUMA1, Default Tier)
# memmap=96G!4G   (NUMA0, Alternate Tier)
MEMMAP_PARAMS="memmap=32G!130G memmap=96G!4G"

echo ">>> 正在备份 GRUB 配置文件到 $BACKUP_CONFIG ..."
sudo cp "$GRUB_CONFIG" "$BACKUP_CONFIG"

echo ">>> 正在修改 $GRUB_CONFIG ..."

# 检查 GRUB_CMDLINE_LINUX 是否已经包含这些参数
if grep -q "$MEMMAP_PARAMS" "$GRUB_CONFIG"; then
    echo ">>> 检测到 GRUB 配置中已包含相关 memmap 参数，无需修改。"
else
    # 使用 sed 在 GRUB_CMDLINE_LINUX 行末尾添加参数
    # 假设 GRUB_CMDLINE_LINUX 格式为 GRUB_CMDLINE_LINUX="..."
    # 如果原本是空的 GRUB_CMDLINE_LINUX=""，这也能工作
    
    # 这里的逻辑是：找到 GRUB_CMDLINE_LINUX="...的内容..."，替换为 GRUB_CMDLINE_LINUX="...的内容... memmap=..."
    # 注意处理原本内容末尾可能有也可能没有引号的情况
    
    sudo sed -i "s/GRUB_CMDLINE_LINUX=\"\(.*\)\"/GRUB_CMDLINE_LINUX=\"\1 $MEMMAP_PARAMS\"/" "$GRUB_CONFIG"
    
    echo ">>> 修改完成。新的配置行如下:"
    grep "GRUB_CMDLINE_LINUX" "$GRUB_CONFIG"
fi

echo ">>> 正在更新 GRUB (update-grub) ..."
if command -v update-grub &> /dev/null; then
    sudo update-grub
elif command -v grub2-mkconfig &> /dev/null; then
    # 对于 RHEL/CentOS/Fedora
    sudo grub2-mkconfig -o /boot/grub2/grub.cfg
else
    echo ">>> 错误：找不到 update-grub 或 grub2-mkconfig 命令。请手动更新 GRUB。"
    exit 1
fi

echo ">>> GRUB 更新完成。"
echo ">>> 请重启系统以使更改生效：sudo reboot"
