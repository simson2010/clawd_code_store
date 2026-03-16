# Mergeable Library 内部机制

> 原文：[kateinoigakukun/MergeableLibraryInternals](https://github.com/kateinoigakukun/MergeableLibraryInternals)
> 翻译：King Lobster 🦞

---

## Mergeable Library 概述

请注意，本文档是非官方的，未来可能会更改。

## 引言

Mergeable Library 是 Mach-O 的可链接库格式。它的设计目标是能够将链接策略（动态链接或静态链接）的决定推迟到最终链接步骤。

传统的链接方式需要在创建库时决定链接策略：

- 动态链接库 (.dylib) 由链接器 (ld) 使用 `-dylib` 选项创建，不包含重定位信息。
- 静态链接库 (.a) 由归档器 (ar) 创建，它保留输入的重定位信息。

### 链接动态库 Foo

```bash
$ clang -c Foo.c -o Foo.o
$ ld Foo.o -dylib -o libFoo.dylib -lSystem -syslibroot $(xcrun --show-sdk-path)
```

### 链接静态库 Foo

```bash
$ clang -c Foo.c -o Foo.o
$ ar rcs libFoo.a Foo.o
```

此外，这两种库格式在运行时镜像文件标识方面有所不同。动态库在运行时有自己的文件，但静态库没有。NSBundle 依赖于镜像文件标识来查找 framework 资源，因此静态库在运行时无法拥有自己的 framework 资源。要从静态库代码引用资源，必须引用其他 frameworks 或 bundles。

因此，很难在静态链接和动态链接之间保持相同的项目结构。

Mergeable Library 正是为解决这些问题而设计的。它是一种 Mach-O 可链接库格式，可以同时作为动态库和静态库链接。它的设计还使其能够像动态库一样拥有自己的 framework 资源，即使在静态链接的情况下也可以。

Mergeable Library 文件可以被视为一种特殊形式的动态库。与动态库的区别在于，Mergeable Library 包含重定位信息，这些信息用于静态链接它（存储在 LC_ATOM_INFO 的 payload 中）。

可以通过以下命令创建 Mergeable Library：

```bash
$ clang -c Foo.c -o Foo.o
$ ld Foo.o -dylib -make_mergeable -o libFoo.dylib -lSystem -syslibroot $(xcrun --show-sdk-path)
$ ld -L. -lFoo main.o -o Run-Dynamic -lSystem -syslibroot $(xcrun --show-sdk-path)
$ ld -L. -merge-lFoo main.o -o Run-Static -lSystem -syslibroot $(xcrun --show-sdk-path)
```

请注意，链接步骤使用 `-make_mergeable` 选项向输出的 mergeable library 添加重定位信息。`-l` 用于动态链接 mergeable library，`-merge-l` 用于静态链接。

Mergeable Library 可以嵌入到 framework 中，可以使用 `-framework` 链接器选项进行动态链接，或使用 `-merge_framework` 选项进行静态链接。合并后的 framework 可以嵌入到 app bundle 中，并且该 framework 有一个空的库二进制文件。

## LC_ATOM_INFO 段

如上一节所述，LC_ATOM_INFO load command 的 payload 包含用于将库静态链接到最终镜像文件的重定位信息。load command 类型是在 Xcode 15 中添加的，你可以在随 Xcode 发布的每个平台 SDK 的 mach-o/loader.h 中找到其定义。LC_ATOM_INFO 的 segment payload 目前尚不清楚，但看起来它与常规的重定位信息格式不同，正如它的名字所暗示的，它可能是 Darwin 链接器内部表示 [Atom](https://opensource.apple.com/source/ld64/ld64-136/doc/design/linker.html#:~:text=non%2Dlive%20atoms.-,Atom%20model) 的序列化格式。Atom 保存了足够的信息来重现重定位信息。

```c
#define LC_ATOM_INFO 0x36 /* 与 linkedit_data_command 一起使用 */

/*
 * linkedit_data_command 包含 __LINKEDIT 段中数据块的偏移量和大小。
 */
struct linkedit_data_command {
    uint32_t cmd; /* LC_CODE_SIGNATURE, LC_SEGMENT_SPLIT_INFO,
                   LC_FUNCTION_STARTS, LC_DATA_IN_CODE,
                   LC_DYLIB_CODE_SIGN_DRS, LC_ATOM_INFO,
                   LC_LINKER_OPTIMIZATION_HINT,
                   LC_DYLD_EXPORTS_TRIE, 或
                   LC_DYLD_CHAINED_FIXUPS。 */
    uint32_t cmdsize; /* sizeof(struct linkedit_data_command) */
    uint32_t dataoff; /* __LINKEDIT 段中的文件偏移 */
    uint32_t datasize; /* 数据文件大小 */
};
```

## Bundle(for: AnyClass) Hook（用于静态链接的 Mergeable Library）

Foundation 的 Bundle(for: AnyClass) 查找包含给定类代码的 bundle 路径。它通常用于引用 framework 本地的资源。

它在内部使用 class_getImageName [1](#user-content-fn-1-4631b5f11e8c21c2c54abf03ec2ee1df) [2](#user-content-fn-2-4631b5f11e8c21c2c54abf03ec2ee1df) 获取给定类的镜像文件路径。class_getImageName 根据给定的类代码地址返回动态库名称。

默认情况下，class_getImageName 使用 dyld_image_path_containing_address 查找包含给定类代码的镜像文件路径。 [3](#user-content-fn-3-4631b5f11e8c21c2c54abf03ec2ee1df)

```objc
/**
 * 返回类源自的动态库名称。
 *
 * @param cls 你要查询的类。
 *
 * @return 包含此类的库名称。
 */
OBJC_EXPORT const char * _Nullable
class_getImageName(Class _Nullable cls)
```

然而，静态链接的库没有自己的镜像文件，所以 dyld_image_path_containing_address 返回的是链接后的镜像文件路径，而不是静态库路径。

这种差异使得 Bundle(for: AnyClass) 根据 mergeable library 是静态链接还是动态链接返回不同的路径。

为了解决这个问题，Darwin 链接器在静态链接 mergeable framework 时（-merge_framework）会合成一段代码和数据到链接后的镜像中。链接器合成的代码通过 [static constructor](https://gcc.gnu.org/onlinedocs/gccint/Initialization.html) 被调用，它通过 [objc_setHook_getImageName](https://github.com/apple-oss-distributions/objc4/blob/689525d556eb3dee1ffb700423bccf5ecc501dbf/runtime/runtime.h#L1713-L1732) 安装 class_getImageName 的 hook。这个 hook 也用于使链接器理解 Swift 类，以及解析 dyld 共享缓存的 framework 身份。

```objc
/**
 * 安装 class_getImageName() 的 hook。
 *
 * @param newValue 要安装的 hook 函数。
 * @param outOldValue 函数指针变量的地址。返回时，旧的 hook 函数存储在该变量中。
 *
 * @note 对 *outOldValue 的存储是线程安全的：即使你的新 hook 在 setter 完成之前从另一个线程被调用，该变量也会在 class_getImageName() 调用你的新 hook 读取它之前更新。
 * @note 链中的第一个 hook 是 class_getImageName() 的原生实现。你的 hook 应该对你不识别的类调用之前的 hook。
 *
 * @see class_getImageName
 * @see objc_hook_getImageName
 */
OBJC_EXPORT void objc_setHook_getImageName(objc_hook_getImageName _Nonnull newValue,
    objc_hook_getImageName _Nullable * _Nonnull outOldValue)
```

链接器合成的 static constructor 代码如下。它安装 `__ZL13imageNameHookP10objc_classPPKc`（imageNameHook(objc_class*, char const**)[4](#user-content-fn-4-4631b5f11e8c21c2c54abf03ec2ee1df)）作为 hook，这也是由链接器生成的。

这些代码序列直接嵌入在 ld-prime 中，可以在每个平台的 ld-prime 二进制文件中找到为 BundleForClassHook_macos_arm64、BundleForClassHook_macos_arm64 等形式。（你可以在 ld-prime 二进制中看到以 cf fa ed fe 开头的内容，这是 Mach-O 二进制的魔数）

```
(__TEXT,__text) section
__ZL11constructorv:
100004000: fd 7b bf a9 stp x29, x30, [sp, #-16]!
100004004: fd 03 00 91 mov x29, sp
100004008: 00 00 00 b0 adrp x0, 1 ; 0x100005000
10000400c: 00 c0 2d 91 add x0, x0, #2928 ; literal pool for: "s14PartialKeyPathCyytG"
100004010: c1 02 80 52 mov w1, #22
100004014: 02 00 80 d2 mov x2, #0
100004018: 03 00 80 d2 mov x3, #0
10000401c: 18 05 00 94 bl 0x10000547c ; symbol stub for: _swift_getTypeByMangledNameInContext
100004020: 00 00 00 90 adrp x0, 0 ; 0x100004000
100004024: 00 e0 00 91 add x0, x0, #56 ; __ZL13imageNameHookP10objc_classPPKc
100004028: 41 00 00 90 adrp x1, 8 ; 0x10000c000
10000402c: 21 00 1d 91 add x1, x1, #1856
100004030: fd 7b c1 a8 ldp x29, x30, [sp], #16
100004034: fa 04 00 14 b 0x10000541c ; symbol stub for: _objc_setHook_getImageName
```

当调用 class_getImageName 时，会调用 imageNameHook 函数。它返回代码被静态链接但资源保存在嵌入 framework 中的合并 framework 路径。以下是 imageNameHook 的伪代码：

```cpp
struct FrameworkLocation {
    const char *name;
    void *unknown;
};

struct LibraryClass {
    void *isa;
    FrameworkLocation *location;
};

static FrameworkLocation relinkableLibraryFrameworkLocations[] = {
    { "MyUI", NULL },
    { "MyUI", NULL },
    { "MyUI", NULL },
    { "MyUI", NULL },
};

static LibraryClass relinkableLibraryClasses[] = {
    { (void *)&_OBJC_CLASS_$_Foo, &relinkableLibraryFrameworkLocations[0] },
    { (void *)&_OBJC_CLASS_$_Bar, &relinkableLibraryFrameworkLocations[1] },
    { (void *)&_OBJC_CLASS_$_Baz, &relinkableLibraryFrameworkLocations[2] },
    { (void *)&_OBJC_CLASS_$_Qux, &relinkableLibraryFrameworkLocations[3] },
};
static const size_t relinkableLibraryClassesCount = 4;

static std::unordered_map<void *, const char *> classes;
void makeClassMap(void) {
    for (size_t i = 0; i < relinkableLibraryClassesCount; i++) {
        classes.try_emplace(relinkableLibraryClasses[i].isa,
            relinkableLibraryClasses[i].location->name);
    }
}

const char *imageNameHook(Class cls, const char **outOldValue) {
    if (classes.empty()) {
        makeClassMap();
    }
    auto it = classes.find(cls);
    if (it == classes.end()) {
        return original_imageNameHook(cls, outOldValue);
    }
    const char *name = it->second;
    NSString *path = [NSString stringWithFormat:@"Frameworks/%s.framework/%s", name, name];
    NSBundle *bundle = [NSBundle mainBundle];
    NSURL *url = [NSURL URLWithString:path relativeToURL:[bundle bundleURL]];
    return strdup([[url path] fileSystemRepresentation]);
}
```

relinkableLibraryFrameworkLocations、relinkableLibraryClasses 和 relinkableLibraryClassesCount 数据是在链接时生成的。它们的内存布局是通过调试器检查的。

---

## 脚注

- [1] [https://github.com/apple-oss-distributions/objc4/blob/689525d556eb3dee1ffb700423bccf5ecc501dbf/runtime/runtime.h#L1454-L1462](https://github.com/apple-oss-distributions/objc4/blob/689525d556eb3dee1ffb700423bccf5ecc501dbf/runtime/runtime.h#L1454-L1462)
- [2] [https://developer.apple.com/documentation/objectivec/1418539-class_getimagename](https://developer.apple.com/documentation/objectivec/1418539-class_getimagename)
- [3] [https://github.com/apple-oss-distributions/objc4/blob/689525d556eb3dee1ffb700423bccf5ecc501dbf/runtime/objc-runtime.mm#L584-L589](https://github.com/apple-oss-distributions/objc4/blob/689525d556eb3dee1ffb700423bccf5ecc501dbf/runtime/objc-runtime.mm#L584-L589)
- [4] Demangled by `$ llvm-cxxfilt __ZL13imageNameHookP10objc_classPPKc`
