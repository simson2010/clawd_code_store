# iOS Mergeable Framework Metadata 移除指南

## 📋 技术背景

**Mergeable Metadata 存储位置**：
- 存储在 Mach-O 文件的 `LC_ATOM_INFO` 加载命令中（十六进制 `0x36`，十进制 `54`）
- 数据结构为 `linkedit_data_command`
- Payload 位于 `__LINKEDIT` 段，包含序列化的重定位信息（基于 linker 内部的 Atom 模型）
- 启用后约使 dylib 体积**翻倍**

## 🔍 问题场景

对于开启 Mergeable 的 Framework，有部分是**通过 Shell Script 拷贝到 App 的 Bundle** 里，并不直接 Embed AND LINK 到 App Target。因此：
- Xcode 构建系统**不会自动处理**其中的 mergeable metadata
- 导致 App Bundle 里保留了多余的元数据，**增大了体积**
- 需要使用**手工或脚本的方式**将 Metadata 删除

## ✅ 方案一：使用 macOS `strip` 命令（推荐）

### 单文件使用方式

```bash
# 移除 LC_ATOM_INFO 加载命令
strip -no_atom_info /path/to/YourFramework.framework/YourFramework

# 重新签名（必须，否则签名会失效）
codesign -f -s - /path/to/YourFramework.framework/YourFramework
```

### `strip` 命令相关选项说明

| 选项 | 影响的 Load Command | 说明 |
|------|---------------------|------|
| `-no_atom_info` | `LC_ATOM_INFO` | 移除 atom info 加载命令及其 payload |
| `-no_uuid` | `LC_UUID` | 移除 UUID 加载命令 |
| `-no_split_info` | `LC_SEGMENT_SPLIT_INFO` | 移除 segment split info 及其 payload |
| `-no_code_signature_warning` | — | 抑制代码签名失效警告 |

### 符号移除选项

| 选项 | 说明 |
|------|------|
| `-S` | 移除调试符号表条目 |
| `-X` | 移除以 `L` 开头的本地符号 |
| `-T` | 移除 Swift 符号（`_$S` 或 `_$s` 前缀） |
| `-N` | 移除所有 nlist 符号和字符串表（动态链接二进制文件） |
| `-x` | 移除所有本地符号（仅保留全局符号） |
| `-c` | 移除段内容以创建 stub 库 |

## 🔧 完整 Shell 脚本

保存为 `strip_mergeable_metadata.sh`：

```bash
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
```

### 在 Xcode Build Phase 中使用

在你的 Shell Script 中，拷贝 framework 后调用：

```bash
# 你的现有拷贝脚本...
cp -R "${SRCROOT}/Frameworks/SomeFramework.framework" "${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/"

# 添加这行来移除 metadata
strip -no_atom_info "${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/SomeFramework.framework/SomeFramework"

# 重新签名
codesign -f -s - "${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/SomeFramework.framework/SomeFramework"
```

## 🐍 方案二：Python 跨平台脚本（使用 LIEF）

如果你需要在 **Windows** 上运行，或者想要更可控的方式：

### 安装依赖

```bash
pip install lief
```

### Python 脚本

```python
#!/usr/bin/env python3
"""
移除 Mach-O 二进制文件中的 LC_ATOM_INFO 加载命令
支持 thin 和 fat (universal) 二进制文件
"""

import sys
import os
import shutil
from pathlib import Path

try:
    import lief
except ImportError:
    print("❌ 请先安装 LIEF: pip install lief")
    sys.exit(1)

LC_ATOM_INFO_VALUE = 0x36  # LC_ATOM_INFO 的加载命令值

def has_atom_info(binary) -> bool:
    """检查二进制文件是否包含 LC_ATOM_INFO 加载命令"""
    for cmd in binary.commands:
        if cmd.command == LC_ATOM_INFO_VALUE:
            return True
    return False

def remove_atom_info_from_binary(binary) -> bool:
    """
    从 LIEF binary 对象中移除 LC_ATOM_INFO 加载命令
    返回是否进行了修改
    """
    modified = False
    
    # LIEF 的 API 可能因版本不同而变化
    # 尝试多种方式移除加载命令
    
    # 方法1: 如果有 remove_command 方法
    if hasattr(binary, 'remove_command'):
        for cmd in list(binary.commands):
            if cmd.command == LC_ATOM_INFO_VALUE:
                binary.remove_command(cmd)
                modified = True
                print(f"   ✅ 移除加载命令: LC_ATOM_INFO")
    
    # 方法2: 通过重建二进制文件的方式
    # （如果方法1不可用）
    
    return modified

def process_macho_file(input_path: str, output_path: str = None) -> bool:
    """
    处理 Mach-O 文件，移除 LC_ATOM_INFO
    
    Args:
        input_path: 输入文件路径
        output_path: 输出文件路径（None 则覆盖原文件）
    
    Returns:
        bool: 是否成功处理
    """
    if output_path is None:
        output_path = input_path + ".tmp"
    
    print(f"🔍 处理: {input_path}")
    
    try:
        binary = lief.parse(input_path)
        
        if binary is None:
            print(f"   ⚠️  无法解析文件（可能不是 Mach-O 格式）")
            return False
        
        # 检查是否为 FAT (universal) 二进制
        is_fat = hasattr(binary, 'fat') and binary.fat is not None
        
        modified = False
        
        if is_fat:
            # 处理 FAT 二进制中的每个架构
            print(f"   📦 FAT 二进制，包含 {len(binary.fat.macho)} 个架构")
            for i, macho in enumerate(binary.fat.macho):
                if has_atom_info(macho):
                    print(f"   🔧 架构 {i+1}: 发现 LC_ATOM_INFO")
                    if remove_atom_info_from_binary(macho):
                        modified = True
                else:
                    print(f"   ⏭️  架构 {i+1}: 不含 LC_ATOM_INFO")
        else:
            # 处理单个架构
            if has_atom_info(binary):
                print(f"   🔧 发现 LC_ATOM_INFO")
                if remove_atom_info_from_binary(binary):
                    modified = True
            else:
                print(f"   ⏭️  不含 LC_ATOM_INFO，跳过")
                return False
        
        if modified:
            # 写入修改后的二进制文件
            binary.write(output_path)
            
            # 如果输出路径是临时文件，替换原文件
            if output_path.endswith(".tmp"):
                shutil.move(output_path, input_path)
            
            print(f"   ✅ 完成!")
            return True
        else:
            print(f"   ⏭️  无需修改")
            return False
            
    except Exception as e:
        print(f"   ❌ 错误: {e}")
        return False

def process_framework(framework_path: str) -> bool:
    """处理 .framework 目录"""
    framework_name = os.path.basename(framework_path).replace(".framework", "")
    binary_path = os.path.join(framework_path, framework_name)
    
    if not os.path.isfile(binary_path):
        print(f"⚠️  找不到二进制文件: {binary_path}")
        return False
    
    return process_macho_file(binary_path)

def main():
    if len(sys.argv) < 2:
        print("用法:")
        print(f"  {sys.argv[0]} <文件或目录路径>")
        print(f"  {sys.argv[0]} /path/to/YourApp.app")
        print(f"  {sys.argv[0]} /path/to/YourFramework.framework")
        sys.exit(1)
    
    target_path = sys.argv[1]
    
    if os.path.isdir(target_path):
        if target_path.endswith(".framework"):
            # 处理单个 framework
            process_framework(target_path)
        else:
            # 查找目录中所有的 framework
            print(f"📦 扫描目录: {target_path}")
            print("")
            for root, dirs, files in os.walk(target_path):
                for d in dirs:
                    if d.endswith(".framework"):
                        framework_path = os.path.join(root, d)
                        process_framework(framework_path)
                        print("")
    else:
        # 处理单个文件
        process_macho_file(target_path)
    
    print("")
    print("✅ 处理完成!")

if __name__ == "__main__":
    main()
```

## 📊 方案对比

| 特性 | `strip -no_atom_info` | Python + LIEF |
|------|----------------------|---------------|
| **平台** | 仅 macOS | 跨平台（macOS/Windows/Linux） |
| **速度** | 快 | 较慢 |
| **可靠性** | 高（官方工具） | 中等（依赖 LIEF 版本） |
| **复杂度** | 简单 | 中等 |
| **Fat Binary 支持** | ✅ | ✅ |
| **需要重新签名** | ✅ | ✅ |

## ⚠️ 重要注意事项

### 1. 重新签名（必须！）

移除 `LC_ATOM_INFO` 后，再次签名是**必须**的：

```bash
# Ad-hoc 签名（开发/测试用）
codesign -f -s - /path/to/framework.dylib

# 使用开发者证书签名
codesign -f -s "Your Developer Certificate" /path/to/framework.dylib
```

### 2. 验证移除结果

```bash
# 检查 LC_ATOM_INFO 是否已移除
otool -l /path/to/framework.dylib | grep LC_ATOM_INFO
# 无输出 = 已成功移除

# 检查文件大小变化
ls -lh /path/to/framework.dylib
```

### 3. 处理 Fat (Universal) 二进制

`strip -no_atom_info` 会自动处理 FAT 二进制中的所有架构切片。

## 🚀 推荐工作流

```bash
#!/bin/bash
# 在你的拷贝脚本中使用

FRAMEWORKS_DIR="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"

# 1. 拷贝 framework
cp -R "${SRCROOT}/Frameworks/SomeFramework.framework" "$FRAMEWORKS_DIR/"

# 2. 移除 mergeable metadata
strip -no_atom_info "$FRAMEWORKS_DIR/SomeFramework.framework/SomeFramework"

# 3. 重新签名
codesign -f -s - "$FRAMEWORKS_DIR/SomeFramework.framework/SomeFramework"

echo "✅ SomeFramework 处理完成"
```

## 📚 参考资源

- [Apple 官方文档：Configuring your project to use mergeable libraries](https://developer.apple.com/documentation/xcode/configuring-your-project-to-use-mergeable-libraries)
- [WWDC 2023 Session 10268: Meet mergeable libraries](https://wwdcnotes.com/documentation/wwdcnotes/wwdc23-10268-meet-mergeable-libraries/)
- [MergeableLibraryInternals GitHub](https://github.com/kateinoigakukun/MergeableLibraryInternals)
- [LIEF Documentation](https://lief.re/doc/latest/)
- [llvm-strip 文档](https://llvm.org/docs/CommandGuide/llvm-strip.html)

## 🔬 技术细节

### LC_ATOM_INFO 数据结构

```c
#define LC_ATOM_INFO 0x36 /* used with linkedit_data_command */

struct linkedit_data_command {
    uint32_t    cmd;            /* LC_ATOM_INFO */
    uint32_t    cmdsize;       /* sizeof(struct linkedit_data_command) */
    uint32_t    dataoff;       /* file offset of data in __LINKEDIT segment */
    uint32_t    datasize;      /* file size of data in __LINKEDIT segment */
};
```

### 检查是否包含 LC_ATOM_INFO

```bash
otool -l /path/to/library.dylib | grep -A4 LC_ATOM_INFO
```

### Mach-O 文件结构

```
Mach-O Header
├── Load Commands
│   ├── LC_SEGMENT_64 (__TEXT)
│   ├── LC_SEGMENT_64 (__DATA)
│   ├── LC_DYLD_INFO_ONLY
│   ├── LC_LOAD_DYLIB
│   ├── LC_ATOM_INFO  ← 需要移除的部分
│   └── ...
└── __LINKEDIT
    └── LC_ATOM_INFO payload
```

## 📝 更新日志

- **2026-05-17**: 初始版本，基于深度调研结果编写
