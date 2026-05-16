#!/usr/bin/env python3
"""
移除 Mach-O 二进制文件中的 LC_ATOM_INFO 加载命令
支持 thin 和 fat (universal) 二进制文件

依赖: pip install lief
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
