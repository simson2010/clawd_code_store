# dyld4 设计

dyld4 的目标是通过保持相同的 mach-o 解析器来改进 dyld3，并在非客户场景下通过支持即时加载（不需要预构建的闭包）来做得更好。

## 源代码组织

* `__dyld/`` - 贡献给 dyld 的代码
* `__libdyld/`` - 贡献给 libdyld.dylib 的代码
* `__cache-builder/`` - 用于工具（如 dyld_usage、dyld_info、dyld_shared_cache_builder 等）的代码
* `__other-tools/`` - 用于工具的代码
* `__common/`` - dyld 和 cache-builder 之间共享的通用代码
* `__include/`` - 公共头文件
* `__testing/`` - 用于测试 dyld 的所有内容
* `__doc/`` - 手册页和其他文档
* `__configs/`` - 目标使用的 xcconfig 文件
* `__build-scripts/`` - shell 脚本阶段脚本

## dyld

dyld4 的模型是 libdyld.dylib 是薄层，而 dyld 包含所有运行时代码。

### 启动

内核通过将所有 argc、argv、envp 和 apple 参数压入堆栈，并跳转到 dyld 的入口点来启动进程。在 dyld4 中，有几行汇编代码用于对齐堆栈，并跳转到带有指向 KernelArgs 指针的 C++ 代码。

### 全局状态

所有 dyld 状态都保存在 dyld 中（不在 libdyld 中），分为两个类：

* `DyldProcessConfig` 保存有关进程的所有固定状态信息（例如安全策略、dyld 缓存、日志标志、平台等）。该对象在 dyld 的 `__DATA_CONST` 段中构造，然后被设为只读，因此它是一个 const 对象。
* 其他状态保存在 `DyldRuntimeState` 中，包括在进程生命周期内变化的所有状态。它包括 Loader 对象列表、注册的通知函数和所有锁。

`DyldRuntimeState` 包含一个指向 `DyldProcessConfig` 对象的指针，因此你可以从 `state` 对象获取 `config` 对象。为了支持单元测试，`DyldRuntimeState` 不是全局变量。相反，`DyldRuntimeState` 对象在 dyld 的 `start()` 函数中在堆栈上分配，并作为参数传递给任何需要它的函数。

### Loader 对象

每个加载的 mach-o 文件都由一个 `dyld4::Loader` 对象跟踪。

在 dyld2 中，我们有一个大的 ImageLoader 图。在 dyld3 中，我们使用一个 Array<>，其中包含两个指针：一个指向 mach_header，另一个指向闭包 Image。在 dyld4 中，已加载映像列表是 `DyldRuntimeState` 中的一个 `Array<dyld4::Loader*>`。

`dyld4::Loader*` 上有一个 `loadAddress()` 方法来获取 `mach_header*`。对于 dyld 缓存中的内容，`PrebuiltLoader` 的实现是快速的，因为它只是 dyld 缓存头的一个偏移量。对于不在 dyld 缓存中的 `PrebuiltLoader`，有一个并行的 `mach_header` 指针数组。另一方面，`JustInTimeLoader` 对象是 malloc() 分配的，并包含一个指向其关联 `mach_header` 的直接指针（就像 dyld2 中的 ImageLoader 一样）。

### MachOAnalyzer

`dyld4::Loader` 对象不直接解析/处理 mach-o 文件。相反，它们是 `dyld3::MachOAnalyzer` 层之上的薄对象。目前，我们仍然保持 `MachOFile`、`MachOLoaded` 和 `MachOAnalyzer` 的分离（来自 dyld3 设计）。将来我们可能想要合并 `MachOLoaded` 和 `MachOAnalyzer`，因为这种分离在 dyld4 的世界中没有意义。

### 无模式

在 dyld3 的推出过程中，我们能够通过回退到 dyld2 来规避（推迟）dyld3 中的问题。但这意味着我们在 dyld 和 libdyld 中有两个所有东西的实现。这也使得我们的客户难以知道进程运行在哪种 dyld 模式下。

在 dyld4 中，只有一个代码库。但是，在逐个映像的基础上，我们实例化 `PrebuiltLoader` 或 `JustInTimeLoader`。这意味着性能有一个很好的连续性。客户安装处处使用 `PrebuiltLoader`。随着内部安装上安装更多根（roots），会使用更多 `JustInTimeLoader`，这些加载器速度较慢。

### 统一的 Prebuilt 和 JustInTime 模型

当前的 dyld3 模型有两个问题：根（roots）和版本。我们已经看到了很多根错误，即我们没有使一些预计算的信息失效。但我也担心闭包版本问题。目前，我们在 dyld 缓存中有预构建的闭包，然后在 dyld 和 libdyld.dylib 中有生成和处理闭包的代码。这意味着这三者是版本锁定的，但没有办法强制执行。例如，如果我们需要在 macOS 中为某些安全原因更改闭包格式，我们可以安装新的 dyld 和 libdyld.dylib，但这些需要能够处理 dyld 缓存中的旧格式闭包（直到重启）。目前我们通过回退到 dyld2 模式来解决这个问题。但我们希望消除 dyld2 模式。

我们设计 dyld3 是为了在常见客户场景（即 OS 不变、应用程序不变）下达到最优。使用 dyld3，我们可以（提前）计算启动任何进程所需的内容。计算闭包是昂贵的（时间和空间），但当它被反复使用时是值得的。但是，随着时间的推移，我们发现，在 Apple 内部，我们很少处于常见场景。OS 和应用程序总是在变化（根）。并且由于系统中大量使用 dlopen，我们经常决定使用 dyld3 模式，但在 dlopen() 期间发现安装了根，这使得所有预构建的闭包失效，需要重新构建它们，这很昂贵。

dyld4 的模型不同。我们有一个新的抽象基类 `Loader`。为进程中加载的每个 mach-o 文件实例化一个 Loader 对象。Loader 类有十个伪虚方法。Loader 有两个具体子类：`PrebuiltLoader` 和 `JustInTimeLoader`。`PrebuiltLoader` 和 `JustInTimeLoader` 类各自对这些伪虚方法有不同的实现。伪虚方法的示例有：`isValid()`、`loadAddress()`、`path()`、`applyFixups()`、`runInitializers()`、`dependent()` 等。

这些类上的十个伪虚方法并不是真正的 C++ 虚方法，因为这需要在对象中有一个 vtable 指针，而我们希望 `PrebuiltLoader` 对象可以从磁盘映射为只读。相反，每个对象的开头包含一个"kind"位，基类 `Loader` 的这些方法实现检查该字段，并跳转到 `PrebuiltLoader` 或 `JustInTimeLoader` 的实现。

**一个重要的约束是 `PrebuiltLoader` 只能有其他 `PrebuiltLoader` 作为依赖项。** 另一方面，`JustInTimeLoader` 可以有任一类型作为依赖项。在没有根的情况下，可以有一个应用程序的 `PrebuiltLoader`，它是启动该应用程序所需的所有内容的 `PrebuiltLoader` 图的顶部。在 dyld 共享缓存中，有 OS 中每个程序的预构建 `PrebuiltLoader` 图，这些图通过共享节点重叠（例如，`/usr/bin/true` 和 `/usr/bin/false` 的 `PrebuiltLoader` 都指向同一个 `libSystem.B.dylib` 的 `PrebuiltLoader`）。

#### PrebuiltLoader 和 PrebuiltLoaderSet

`PrebuiltLoader` 始终是只读的。它包含关于其 mach-o 文件的预计算信息，包括其路径、验证信息、其依赖的 dylib 以及预计算绑定目标的数组。`PrebuiltLoader` 中使用 16 位的 `LoaderRef` 来引用其他 Loader。由于 `PrebuiltLoader` 对象只能依赖于其他 `PrebuiltLoader` 对象，并且一个进程中最多有两个 `PrebuiltLoaderSet`，因此 `LoaderRef` 有一个位来指定哪个 `PrebuiltLoaderSet`，以及 15 位来指定该集合中的索引。预计算的绑定目标编码为 `<LoaderRef, offset>`。

`PrebuiltLoader` 对象被分组到一个 `PrebuiltLoaderSet` 中，这是一个可以保存到磁盘并 `mmap()` 回内存的数据结构。任何进程中最多有两个 `PrebuiltLoaderSet` 对象可用。一个在 dyld 缓存中，包含作为 dyld 共享缓存一部分的每个 dylib 的 `PrebuiltLoader`。另一个是每个应用程序的 `PrebuiltLoaderSet`。

每个应用程序的 `PrebuiltLoaderSet` 来自两个位置：dyld 缓存或文件。当构建 dyld 缓存时，所有 OS 主可执行文件都会构建一个 `PrebuiltLoaderSet` 并存储在 dyld 缓存中。dyld 缓存中有一个 trie，将程序路径映射到 `PrebuiltLoaderSet`。

Dyld 可以在一种模式下启动，即如果进程使用 `JustInTimeLoader`，在所有映像加载之后、任何初始化程序运行之前，dyld 将 `JustInTimeLoader` 对象"克隆"到 `PrebuiltLoader` 对象，然后将这些对象打包到一个 `PrebuiltLoaderSet` 中，并将其写入磁盘。该保存的 `PrebuiltLoaderSet` 相当于 dyld3 的闭包文件。

#### JustInTimeLoader

每个 `JustInTimeLoader` 都是一个 malloc() 分配的对象，包含一个指向其 mach_header 的指针，以及一些标志和一个其依赖项的 `Loader*` 数组。它通过使用 `MachOAnalyzer` 在需要时解析其 mach-o 文件来实现十个伪虚方法。

在启动时，dyld 查找程序的预构建 `PrebuiltLoader`。如果找到，则调用其 `isValid()` 方法，该方法递归调用其依赖 dylib 的 `isValid()`。如果程序 `PrebuiltLoader` 有效，则使用它。如果无效，则创建并使用新的 `JustInTimeLoader`。`JustInTimeLoader` 然后通过解析 mach-o 来查找其依赖项。对于每个依赖项，执行相同的技巧，即查找现有的 `PrebuiltLoader` 以重用。完成此操作后，你将得到一个图，顶部有一个 `JustInTimeLoader`，并且仍然有效的任何子图使用预构建的 `PrebuiltLoader`，只有根 dylib 及其上的映像在图中的相应部分使用 `JustInTimeLoader` 对象。

由于 `PrebuiltLoader` 和 `JustInTimeLoader` 对象是可互换的，它提供了一种在两者之间平滑移动以进行测试覆盖的方法。例如，如果没有 dyld 缓存，则没有 `PrebuiltLoader` 对象——所有内容都是 `JustInTimeLoader`（如 dyld2 模式）。在客户 iOS 设备上，OS 中的所有内容都有预构建的 `PrebuiltLoader`，因此所有这些都以 dyld3 速度启动。对于开发，我们还可以有一个引导参数或环境变量来控制何时强制使 `PrebuiltLoader` 失效，这会导致 dyld 使用 `JustInTimeLoader`。

## libdyld.dylib

libdyld.dylib 很小。几乎所有代码都在 dyld 中。一个例外是 `_dyld_process_info` 例程，它们不使用任何当前的 dyld 状态，而是检查另一个进程的 dyld 状态。可能在某些时候将该代码分解到 libSystem 下的一个新的 dylib 中。

鉴于 libdyld.dylib 是薄层并且只是跳转到 dyld，有两个有趣的问题需要解决：1) 使用哪种跳转表，2) dyld 中的 API 函数如何访问 `DyldRuntimeState` 对象。解决这两个问题的解决方案是声明一个新类 `APIs`，它是 `DyldRuntimeState` 的子类，并具有 dyld 中所有 API 和 SPI 的虚方法。然后在启动时，dyld 分配一个 APIs 对象（而不是 `DyldRuntimeState` 对象），并将其地址塞入 libdyld.dylib 的一个全局变量（魔术节）中。在 libdyld.dylib 中，每个 API/SPI 都有粘合代码，只需使用 APIs 指针并调用其上的相应虚方法。此外，这种设计简化了单元测试的编写，因为现在单元测试可以调用主机 dyld 函数（例如 `dlopen("xx", 0)`）或可以调用当前代码进行测试（例如 `apis->dlopen("xx", 0)`）。

### libdyld 更改的基本原理

对于 dyld3，我们沿着将大多数代码移动到 libdyld.dylib 的路径前进。想法是长期来看我们会缩小 dyld。最终，内核可以跳过 dyld 的加载，而是将进程的 pc 设置在 libdyld.dylib 中（在 dyld 缓存中），而实际的 dyld 仅需要在引导情况下（例如 dyld 缓存过期或安装了 dyld 根）才需要。

但是，当前的 dyld/libdyld 拆分是有问题的：

1. 在 dyld3 模式下，将控制权从 dyld 移交给 libdyld 的接口是一个复杂的多步骤过程
2. 一旦控制权移交，我们是否能够卸载 dyld 尚不清楚，因为 dyld 中有各种全局状态
3. 闭包版本控制将非常复杂。最坏的情况是，安装了根，使得 dyld、libdyld.dylib 和用于创建活动 dyld 缓存的缓存构建器版本都是不同的版本。由于格式可能不同（版本不同），无法使闭包互操作。
4. 如果我们能够达到内核在 dyld 缓存中的 libdyld.dylib 中启动进程的程度，那么如何初始化 libSystem 尚不清楚。它只能在加载并绑定 libSystem 中的所有映像之后才能初始化。但是，如果 libdyld.dylib 无法使用 libsystem 的部分来执行该工作，它如何加载 libSystem 根？

dyld4 的解决方案是：

A) 回到将所有代码放在 dyld 中
B) 使 libdyld.dylib 成为一个薄垫片，其中 API 使用函数指针表跳转回 dyld
C) 作为优化，让缓存构建器将 dyld 的副本放入 dyld 缓存中。然后更改内核（当不使用 alt-dyld 时）跳过 dyld 加载，而是将初始 pc 设置为 dyld 缓存中的 dyld。

这解决了上述问题：

1. 不再有移交。
2. Dyld 永远不会被卸载，但通过将 dyld 放入共享缓存，我们获得了许多这样的好处
3. 不再需要闭包版本控制。libdyld.dylib 不再包含闭包读/写代码，因此它不会与 dyld 不同步。对于 dyld4，如果有任何根，dyld 缓存中的 `PrebuiltLoader` 对象将无效，因此 dyld 将使用 `JustInTimeLoader` 对象运行进程
4. 因为 dyld 仍然使用静态 libc.a 构建，所以 libSystem dylib 代码只有在 dyld 完成加载所有映像后才会初始化。

## 测试

`testing/` 目录有两个主要的子目录：`test-cases` 和 `unit-tests`。第一个从 .dest 目录生成 BATS 测试，就像在 dyld3 中一样。第二个目录是新的，使用 XCTest。

### 单元测试

对于要测试的每个 dyld 内部块，有一个 `*Tests.mm` 文件。目前有：`DyldProcessConfigTests.mm`、`APITests.mm` 和 `MachOFileTests.mm`。文件是 `.mm` 因为 XCTest 使用 ObjC，而 dyld 内部是用 C++ 编写的。

典型的单元测试遵循 Arrange、Act、Assert 模式。也就是说，Arrange 部分设置所需的对象，Act 部分调用对象上的方法来执行被测试的功能，最后 Assert 部分使用 `XCTAssert()` 宏来验证方法是否按预期执行。

注意，XCTest 并行运行所有 `*test` 方法。这意味着 dyld 中不能有全局变量，因为测试会相互干扰全局变量的使用。这就是为什么所有 dyld"全局变量"必须作为字段放在 `ProcessConfig`（如果在进程生命周期内固定）或 `RuntimeState` 中。

对于 API 测试，单元测试必须调用 APIs 类上的方法（而不是作为正常 dyld API 的全局 C 函数）。这是因为调用全局函数实际上会调用主机 dyld 中的该函数。

### 委托

为了支持可测试性以及在缓存构建器中使用 dyld 代码，所有 dyld 代码都不直接进行 OS 调用或直接访问内核参数。相反，调用通过委托对象进行。这允许在单元测试期间或共享缓存构建期间使用不同的委托对象。

#### SyscallDelegate

`SyscallDelegate` 处理所有 OS 调用（例如打开或映射文件）。有低级（即 posix 级别）方法，如 `open`、`close`、`mmap`。还有更高级别的方法，如 `withReadOnlyMappedFile()`，使得可以轻松交换不同的实现，例如在 MRM 中需要所有文件都已映射到内存中的情况。

除了系统调用，`SyscallDelegate` 还提供对 commpage 和引导参数的访问。基本上是 OS 提供的信息。

当前的实现只有一个 `SyscallDelegate` 类，它使用 `#if` 指令在不同的目标中构建不同。目前不需要动态选择使用哪个 `SyscallDelegate`，因此 `#if` 工作良好。

#### KernelArgs

另一个委托是 `KernelArgs`，它是指向内核传递给 dyld 的堆栈上的信息（例如 argc、argv、envp 等）的指针。这比其他委托更少委托性，因为它是一个开放的数据结构。但 `KernelArgs` 类为单元测试提供了一个简单的包装器，以构造用于测试 `ProcessConfig` 的内核参数。

### MockO

dyld 中有许多处理 mach-o 文件的功能。理论上，你可以将其委托出去，以便可以测试原始 mach-o 解析器之上的逻辑，但这仍然留下 mach-o 解析器需要测试。所以，相反，我们有一个辅助类，可以动态生成内存中的 mach-o 文件。这些在单元测试术语中是"模拟"（mocks）。生成 mach-o 文件的辅助类称为 `MockO`。要使用，你只需构造一个 `MockO` 对象，传入文件类型和体系结构，然后使用方法来添加需要测试的加载命令和内容。

`MockO` 类仍在进行中。目前它只生成有效的 mach_header 和加载命令，但这足以编写单元测试来测试需要检查主可执行文件的 `ProcessConfig`。
