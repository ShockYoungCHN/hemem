#!/bin/bash
set -e

# manage_dax.sh
# 用于创建和删除 HeMem 所需的 DAX 设备。

function usage() {
    echo "用法: $0 [create|destroy|list]"
    echo "  create  : 创建 DAX 命名空间 (默认: namespace0.0 和 namespace1.0)"
    echo "  destroy : 销毁 DAX 命名空间，恢复为默认模式"
    echo "  list    : 列出当前的 ndctl 命名空间"
    exit 1
}

# 默认的命名空间名称，根据你的 `ndctl list` 输出可能需要调整
NS1="namespace0.0" # 对应 NUMA0 / Alternate Tier
NS2="namespace1.0" # 对应 NUMA1 / Default Tier

function check_ndctl() {
    if ! command -v ndctl &> /dev/null; then
        echo ">>> 错误: 未安装 ndctl。请先运行 'sudo apt install ndctl'。"
        exit 1
    fi
}

function list_namespaces() {
    echo ">>> 当前的 ndctl 命名空间:"
    sudo ndctl list
}

function create_dax() {
    echo ">>> 正在创建 DAX 设备 (devdax 模式)..."
    
    # 检查命名空间是否存在
    if ! sudo ndctl list | grep -q "$NS1"; then
        echo ">>> 警告: 未找到 $NS1。请先确认 'ndctl list' 输出并修改脚本中的 NS 变量。"
    else
        echo ">>> 配置 $NS1 ..."
        sudo ndctl create-namespace -f -e "$NS1" --mode=devdax --align 2M
    fi

    if ! sudo ndctl list | grep -q "$NS2"; then
        echo ">>> 警告: 未找到 $NS2。请先确认 'ndctl list' 输出并修改脚本中的 NS 变量。"
    else
        echo ">>> 配置 $NS2 ..."
        sudo ndctl create-namespace -f -e "$NS2" --mode=devdax --align 2M
    fi
    
    echo ">>> DAX 创建操作完成。请检查下方的 chardevs (例如 dax1.0):"
    sudo ndctl list
}

function destroy_dax() {
    echo ">>> 正在销毁/重置 DAX 设备 (恢复默认模式)..."
    # 这里我们尝试将它们重置为 raw 或者 fsdax 模式，通常这意味着“取消”特定的 devdax 配置
    # 或者直接禁用并重新启用以恢复默认（取决于具体需求，通常 create-namespace -f 会覆盖）
    # 但如果目的是完全移除，可以使用 destroy-namespace（如果是动态创建的）或者重新配置为 fsdax
    
    echo ">>> 重置 $NS1 为 fsdax 模式 (默认)..."
    sudo ndctl create-namespace -f -e "$NS1" --mode=fsdax 2>/dev/null || echo "重置 $NS1 失败或不存在"
    
    echo ">>> 重置 $NS2 为 fsdax 模式 (默认)..."
    sudo ndctl create-namespace -f -e "$NS2" --mode=fsdax 2>/dev/null || echo "重置 $NS2 失败或不存在"
    
    echo ">>> 重置完成。"
    sudo ndctl list
}

# Main logic
check_ndctl

case "$1" in
    create)
        create_dax
        ;;
    destroy)
        destroy_dax
        ;;
    list)
        list_namespaces
        ;;
    *)
        usage
        ;;
esac
