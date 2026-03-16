# MergeableLibraryInternals 学习笔记

> 来源：https://github.com/kateinoigakukun/MergeableLibraryInternals

## 什么是 Mergeable Library？

Mergeable Library 是 macOS/iOS 中的一种可链接库格式，专为 Mach-O 设计。它的核心特性是：**可以在最终链接步骤时才决定链接策略**（动态链接 or 静态链接）。

## 传统链接方式的问题

在传统方式中，库的类型在创建时就已经确定：

- **动态库 (.dylib)**：由 linker (`ld`) 使用 `-dylib` 选项创建，不包含重定位信息
- **静态库 (.a)**：由 archiver (`ar`) 创建，保留输入的重定位信息

### 问题 1：项目结构不一致
- 动态库在运行时有自己的文件，但静态库没有
- `NSBundle` 依赖 image file identity 来查找 framework 资源
- 静态库无法在运行时访问其 framework 资源
- 这导致静态链接和动态链接很难保持相同的项目结构

### 问题 2：链接策略必须在开发时决定
开发者必须在项目配置时决定使用动态还是静态链接，无法延迟到最终链接时。

## Mergeable Library 的解决方案

Mergeable Library 可以同时作为动态库和静态库链接：

```bash
# 创建 Mergeable Library
clang -c Foo.c -o Foo.o
ld Foo.o -dylib -make_mergeable -o libFoo.dylib -lSystem -syslibroot $(xcrun --show-sdk-path)

# 动态链接
ld -L. -lFoo main.o -o Run-Dynamic -lSystem -syslibroot $(xcrun --show-sdk-path)

# 静态链接
ld -L. -merge-lFoo main.o -o Run-Static -lSystem -syslibroot $(xcrun --show-sdk-path)
```

关键点：
- `-make_mergeable`：向输出库添加重定位信息
- `-l`：动态链接 mergeable library
- `-merge-l`：静态链接 mergeable library

## 核心技术细节

### 1. LC_ATOM_INFO Load Command

`LC_ATOM_INFO` 是 Xcode 15 新增的 load command，用于存储静态链接所需的重定位信息：

```c
#define LC_ATOM_INFO 0x36

struct linkedit_data_command {
    uint32_t cmd;
    uint32_t cmdsize;
    uint32_t dataoff;  // __LINKEDIT 段中的偏移
    uint32_t datasize;  // 数据大小
};
```

payload 格式是 Darwin 链接器内部 "Atom" 格式的序列化，用于存储重定位信息。

### 2. Bundle(for: AnyClass) Hook 机制

当静态链接 Mergeable Library 时，`Bundle(for: AnyClass)` 的行为会不同：

- **动态库**：返回动态库路径
- **静态库**：返回主程序路径（因为静态库没有自己的 image 文件）

为解决这个问题，Darwin 链接器在静态链接时会：
1. 合成一段代码和数据
2. 通过 static constructor 安装 `objc_setHook_getImageName` hook
3. hook 函数返回正确的 framework 路径

这个 hook 机制使得即使代码被静态链接，`Bundle(for: AnyClass)` 仍能正确找到 framework 资源。

### 3. linker 合成的数据结构

链接时生成的数据结构：
- `relinkableLibraryFrameworkLocations`：framework 名称数组
- `relinkableLibraryClasses`：类与 framework 位置的映射
- `imageNameHook`：实际返回正确路径的 hook 函数

## 注意事项

1. **仅适用于 Mach-O**：Mergeable Library 是 macOS/iOS (Mach-O) 特有的格式
2. **Xcode 15+**：需要 Xcode 15 或更高版本
3. **-make_mergeable 选项**：创建库时必须使用此选项
4. **资源访问**：即使静态链接，也能像动态库一样访问 framework 资源
5. **嵌入 framework**：可以嵌入到 app bundle 中，framework 会有一个空的库二进制文件
6. **非官方文档**：此文档是非官方的，未来可能会更改

## 总结

Mergeable Library 是一个解决 iOS/macOS 开发中静态/动态链接两难问题的方案。它允许开发者在最终链接时才决定策略，同时保持代码和资源的可访问性，是 Apple 生态系统中一个重要的底层机制。
