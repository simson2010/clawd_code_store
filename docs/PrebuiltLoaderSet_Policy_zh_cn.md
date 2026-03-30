# PrebuiltLoaderSet 策略

dyld4 必须为每个加载的 mach-o 文件创建一个 Loader 对象。Loader 对象有两种类型：`PrebuiltLoader` 和 `JustInTimeLoader`。`PrebuiltLoader` 对象更小、更快，且是只读的。`JustInTimeLoader` 对象是通过 malloc() 分配的对象，会在运行时解析 mach-o 文件。

`PrebuiltLoader` 对象被分组到 `PrebuiltLoaderSet` 对象中，这些对象始终位于只读内存中。对于 OS 程序，dyld 缓存构建器会在 dyld 缓存中创建 `PrebuiltLoaderSet` 对象。对于所有其他程序，`PrebuiltLoaderSet` 对象会按需构建并保存到磁盘。在 dyld3 术语中，保存的 `PrebuiltLoaderSet` 被称为闭包文件（closure file）。

本文档描述了 dyld4 中使用 `PrebuiltLoaderSet` 文件的策略。

## 背景：dyld3 策略

近期的 OS 版本同时包含 dyld2 和 dyld3，我们有关于何时使用 dyld3 的策略：

* iOS/tvOS/watchOS：当设备使用客户 dyld 缓存启动时，所有第三方应用和所有内置到 OS 中的程序使用 dyld3。其他非容器化程序以 dyld2 运行
* iOS/tvOS/watchOS：当设备使用开发 dyld 缓存启动时，所有程序使用 dyld2
* macOS：内置到 OS 中的程序使用 dyld3，除非检测到"根"（root）
* macOS：所有 Almond（iPad 应用）以 dyld3 模式运行
* macOS：所有其他程序（包括所有第三方应用）以 dyld2 模式运行

上述策略是基于多种实际原因形成的：

* 内部安装（使用开发 dyld 缓存）通常安装了"根"，而 dyld3 在使闭包失效方面存在 bug
* dyld3 在 mach-o 文件布局方面比 dyld2 更严格。由于 iOS 的所有第三方应用都通过 App Store，我们能够针对所有应用验证 dyld3。而 macOS 没有应用审查机制，许多应用由第三方工具构建
* 在 iOS/tvOS/watchOS 上，所有第三方应用都是"容器化"的，这意味着它们有一个应用专属的主目录，并且被沙盒限制只能在那里写入文件

上述策略的最终结果是，我们唯一需要构建并保存闭包文件到磁盘的场景是：在 iOS/tvOS/watchOS 上使用客户 dyld 缓存运行时的第三方应用。

## dyld4 约束

在 dyld4 中，没有回退到 dyld2 的选项。只有 dyld4。唯一的选项是使用 `JustInTimeLoader` 或 `PrebuiltLoader`。

对于 dyld4，我们希望为所有程序构建并保存 `PrebuiltLoaderSet` 的能力。这是因为在 macOS 上，极少数应用是容器化的，而在 iOS 上有许多内置应用不是容器化的。对于非容器化应用，我们需要将 `PrebuiltLoaderSet` 文件保存到 `~/Library/Caches/com.apple.dyld/` 下的某个唯一名称，以避免不同应用之间发生冲突。

dyld4 在以下情况下不会尝试构建 `PrebuiltLoaderSet`：

* 没有 dyld 缓存（`PrebuiltLoaderSet` 会非常大）
* 主程序链接了使用 interposing 的 dylib（会使 `PrebuiltLoaderSet` 复杂化，且仅在开发期间使用）
* 主程序使用 `DYLD_INSERT_LIBRARIES`、`DYLD_*_PATH` 或 `DYLD_IMAGE_SUFFIX` 启动（会使 `PrebuiltLoaderSet` 复杂化，且仅在开发期间使用）

正在开发某个 OS 内置程序的 Apple 工程师，可能希望获得 `PrebuiltLoader` 的性能。但 dyld 缓存中已经有一个 `PrebuiltLoaderSet`。我们需要一种方法来覆盖该 `PrebuiltLoaderSet`，但又不能引入安全漏洞，使 OS 程序可以通过安装替代的 `PrebuiltLoaderSet` 文件被劫持。

为了测试，我们希望能够通过 `DYLD_USE_CLOSURES` 强制 dyld4 使用或不使用 `PrebuiltLoaderSet`。

我们仍然保持安全要求：闭包文件在重启后不能被使用。这是为了防止攻击者通过这种方式实现持久化。

## dyld4 策略

dyld4 将构建并保存 `PrebuiltLoaderSet`，除非出现以下无法构建的情况：

* 没有 dyld 缓存
* dyld 缓存中的 `PrebuiltLoaderSet` 版本与 dyld 不匹配
* 进程使用 `DYLD_INSERT_LIBRARIES`、`DYLD_*_PATH` 或 `DYLD_IMAGE_SUFFIX` 启动
* dyld 缓存中已存在有效的 `PrebuiltLoaderSet`
* 使用了 interposing
* 使用 `DYLD_USE_CLOSURES` 覆盖默认策略

这与 GoldenGate/Azul 的不同之处在于，现在 `PrebuiltLoaderSet`（闭包文件）会在以下情况下保存/读取：

* 使用开发 dyld 缓存时
* 非容器化应用
* 在 macOS 上
* 内部安装上有根的 OS 程序

可以使用 `DYLD_USE_CLOSURES` 覆盖默认策略。该环境变量当前具有以下含义：

* `DYLD_USE_CLOSURES=0` 表示使用 dyld2
* `DYLD_USE_CLOSURES=1` 表示使用 dyld3
* `DYLD_USE_CLOSURES=2` 表示使用 dyld3s（更小的闭包）

dyld BATS 测试用例目前会对每个测试使用三种 `DYLD_USE_CLOSURES` 值运行，以确保测试在 dyld 以每种模式运行时都能正常工作。

对于 dyld4，我们将该环境变量重新映射为以下含义：

* `DYLD_USE_CLOSURES=0` 表示对主可执行文件使用 `JITLoader`
* `DYLD_USE_CLOSURES=1` 表示对主可执行文件使用 `JITLoader`，然后从 `JITLoader` 构建 `PrebuiltLoaderSet` 并保存到磁盘
* `DYLD_USE_CLOSURES=2` 表示查找 `PrebuiltLoaderSet`，如果尚未构建则失败

## 实现细节

一个完整的 Xcode 内部安装可能有五个左右的 clang 实例，每个在不同的工具链中。我们希望写入一个 `PrebuiltLoaderSet`，以便将来的 clang 启动更快，但 clang 不是容器化的，我们不想让每个版本的 clang 覆盖彼此的 `PrebuiltLoaderSet` 文件。因此，`PrebuiltLoaderSet` 文件的路径是二进制文件的 cdhash（由内核传递给 dyld）和主可执行文件路径的哈希的组合。

检查是否有 dyld 缓存或是否有 `DYLD_*` 环境变量并禁用检查或构建 `PrebuiltLoaderSet` 很容易。但 interposing 比较困难。interposing 的存在直到所有 dylib 加载完成才知道。这意味着 `DYLD_USE_CLOSURES=2` 不能在 `ProcessConfig` 早期就报错。我们必须等待 `JustInTimeLoader` 构建完成，并确认本可以构建 `PrebuiltLoader`。
