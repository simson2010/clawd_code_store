#!/bin/bash
set -e

# ============================================
# 移除 App Bundle 中 Framework 的 Mergeable Metadata
# 使用方法:
#   ./strip_mergeable_metadata.sh /path/to/YourApp.app
# ============================================

TARGET_APP="$1"

if [ -z "$TARGET_APP" ]; then
    echo "❌ 用法: $0 <App Bundle 路径>"
    echo "例如: $0 /path/to/YourApp.app"
    exit 1
fi

if [ ! -d "$TARGET_APP" ]; then
    echo "❌ 找不到 App Bundle: $TARGET_APP"
    exit 1
fi

echo "📦 处理 App Bundle: $TARGET_APP"
echo ""

# 计数器
processed=0
skipped=0
errors=0

# 查找所有 .framework 目录
find "$TARGET_APP" -name "*.framework" -type d | while read -r framework_dir; do
    
    # 获取 framework 名称（目录名去掉 .framework 后缀）
    framework_name=$(basename "$framework_dir" .framework)
    
    # 获取二进制文件路径
    binary_path="$framework_dir/$framework_name"
    
    if [ ! -f "$binary_path" ]; then
        # 有些 framework 的二进制文件名不同，尝试查找
        binary_path=$(find "$framework_dir" -type f -maxdepth 1 -perm +111 2>/dev/null | head -1)
    fi
    
    if [ ! -f "$binary_path" ]; then
        echo "⚠️  跳过 $framework_name (找不到二进制文件)"
        ((skipped++)) || true
        continue
    fi
    
    echo "🔍 检查: $framework_name"
    
    # 检查是否包含 LC_ATOM_INFO 加载命令
    if otool -l "$binary_path" 2>/dev/null | grep -q "LC_ATOM_INFO"; then
        echo "   ✅ 发现 LC_ATOM_INFO，正在移除..."
        
        # 获取原始文件大小
        original_size=$(stat -f%z "$binary_path" 2>/dev/null || stat -c%s "$binary_path" 2>/dev/null)
        
        # 移除 LC_ATOM_INFO
        if strip -no_atom_info "$binary_path" 2>/dev/null; then
            # 重新签名（ad-hoc 签名）
            codesign -f -s - "$binary_path" 2>/dev/null || true
            
            # 获取新文件大小
            new_size=$(stat -f%z "$binary_path" 2>/dev/null || stat -c%s "$binary_path" 2>/dev/null)
            saved=$((original_size - new_size))
            
            echo "   ✅ 完成! 减少 ${saved} bytes"
            ((processed++)) || true
        else
            echo "   ❌ strip 失败"
            ((errors++)) || true
        fi
    else
        echo "   ⏭️  跳过 (不含 LC_ATOM_INFO)"
        ((skipped++)) || true
    fi
    echo ""
done

echo "=========================================="
echo "📊 处理完成!"
echo "   处理: $processed 个 framework"
echo "   跳过: $skipped 个 framework"
echo "   错误: $errors 个"
echo "=========================================="
