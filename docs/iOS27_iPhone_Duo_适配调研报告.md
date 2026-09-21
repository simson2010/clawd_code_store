# iOS 27 + iPhone Duo 适配调研报告

> 调研日期：2026-09-21/22 · 多源交叉验证版（Apple 官网 + Apple Developer Tech Talks + 中/英/日媒体）
> 关键词：iPhone Duo、折叠屏、iOS 27、iOS 27.1 SDK、适配、Xcode 27.1

---

## 核心结论（TL;DR）

苹果**没有**为 iPhone Duo 提供 iPad 应用兼容层，而是采用「编译 SDK 分级」策略：

- **≤ iOS 26 SDK**：应用在内屏以黑边（pillarbox）运行，体验降级
- **iOS 27.0 SDK**：显示区扩展到状态栏左侧，但**强制 Liquid Glass**（兼容退出选项被移除）
- **iOS 27.1 SDK**：真正全屏到边缘 + 系统栏竖排 + Duo 专属新组件
- **死线：2027 年 4 月起，App Store 仅接受 iOS 27+ SDK 构建的上传**

---

## 一、设备与系统基本盘

| 项目 | 内容 |
|---|---|
| 发布 / 发售 | 2026-09-09 发布；10-16 预购；**10-23 正式发售** |
| 售价 | $1,999 起（256GB）；国行电商约 ¥15,999 起，1TB 约 ¥21,499–22,999 |
| 内屏 | 7.6 英寸折叠屏，1878×2670，纳米纹理，**屏下 FaceTime 摄像头** |
| 外屏 | 5.4 英寸，1398×2034，约为 iPhone 18 Pro 显示面积的 90% |
| 双屏共性 | 相同屏幕比例、120Hz ProMotion、3000nit 峰值亮度、全天候显示 |
| 硬件 | A20 Pro + Apple C2 基带，纯 eSIM，侧边 Touch ID，254g，IP68，年内支持 Apple Pencil (USB-C) |
| 系统轨道 | Duo 出厂跑 **iOS 27.1**；其他 iPhone 已走 27.2 beta，两条线后续版本合并 |

信息来源：Apple 中国官网新闻稿、Impress Watch（日本）、京东/天猫商品页，三方参数一致。

---

## 二、适配核心机制：SDK 版本决定显示行为

这是本次调研最关键的发现。苹果刻意不做兼容层，以换取原生折叠体验；代价是开发者必须重新编译。

| 编译 SDK | 内屏表现 | 附加影响 |
|---|---|---|
| ≤ iOS 26 SDK | 原样运行，但左右黑边（pillarbox），UX 明显降级 | 可参与分屏多任务，能缓解部分体验问题 |
| iOS 27.0 SDK | 显示区扩展到状态栏左侧 | Liquid Glass 兼容退出选项被移除（双重负担） |
| iOS 27.1 SDK | 真正全屏到边缘 + 导航/工具/标签栏竖排 | 解锁 Duo 专属新组件与新 API |

> ⚠️ **硬性死线**：2027 年 4 月起，App Store 仅接受 iOS 27 或更高 SDK 构建的应用上传。最迟 2027 年 4 月必须完成适配，否则无法发布更新。

---

## 三、开发工具现状

1. **Xcode 27.1 beta 已发布**（9 月下旬，兑现「9 月底前提供工具」的承诺），要求 Apple silicon Mac + macOS 26.6+
2. 内置 **iPhone Duo 模拟器**（Device Hub），屏幕按钮可模拟开合、旋转、半折等所有姿态
3. ⚠️ **已知坑**：环境停留在 iOS 27.0 时模拟器默认不出现——需到 `Settings > Components` 手动触发 27.1 runtime 下载
4. Apple 已在开发者门户放出 **Figma / Sketch 设计套件**，供界面规划使用

---

## 四、六个 Duo 独有新 API（其他 iPhone 上不存在）

| API（SwiftUI / UIKit） | 作用 |
|---|---|
| `onHingeChange` / `UIHingeInteraction` | 铰链状态（闭合/半开/全开）+ 连续角度；**只用于交互特效，不要用于布局决策** |
| `ArrangementView` / `UIArrangementViewController` | 跨折痕的主/副视图容器，支持 split 与 overlay 两种样式 |
| `ReservedRegion` / `UIViewReservedRegion` | 查询铰链（division region）与屏下摄像头（occlusion region）占位，避免内容碰撞 |
| `UIWindowSceneActivation` | 请求第二窗口——**Duo 是首台支持多开的 iPhone，但新窗口只能开在内屏** |
| `CameraCaptureAccessory` / `.sceneAccessory()` | 相机在内屏全屏时，外屏显示附加 UI（提词器、被摄者预览等） |
| Virtual Front Camera | `AVCaptureDeviceDiscoverySession` + `AVCaptureDeviceDirectionCoordinator`，前后摄像头随开合自动切换 |

---

## 五、布局适配准则（官方 Tech Talks 提炼）

1. **用 size class，不用 orientation**：内屏不再响应 `supportedInterfaceOrientations`；外屏 compact、内屏 regular×regular。不要按 5 种姿态各做一套布局，只做 compact / regular 两套
2. **弃用 `UIScreen.main`**（双屏设备语义模糊，将废弃）→ 改用 `window?.windowScene?.screen` / `traitCollection.displayScale`
3. **safe area 左右不对称**：别再假设 `left == right`，每侧独立计算
4. **标准容器自动适配**：`NavigationSplitView`、`TabView`、`UISplitViewController`、`UITabBarController` 全姿态自适应；**自定义导航栏/标签栏不会**被系统转换——是迁移标准组件的好时机
5. **内屏可选竖排侧边栏**：SwiftUI `.defaultTabBarPlacement(.sidebar)`；UIKit `tabBarController.sidebar.preferredPlacement`
6. **竖排栏规则**：图标型控件转竖排，纯文本控件保持横排；导航类（返回/关闭）置顶，主操作（完成）随后，空间不足时按序进入溢出菜单
7. **折痕避让（displacement）**：交互元素远离铰链，滚动内容例外；sheet / alert / popover 系统会自动避让，自定义网格需自行处理
8. **分屏多任务是硬要求**：所有 App 都参与内屏双 App 并排，可缩放性（resizability）必备；游戏/视频还需处理「视频 + App」堆叠布局

---

## 六、风险与行业观点

- **苹果的刻意赌博**：拒绝 iPad 二进制兼容层保证了 Duo 的原生体验，但首发期大量 App 会「困在黑边里」，生态初期体验可能粗糙
- **Liquid Glass + Duo 双重强制**：重编译即失去 Liquid Glass 退出选项，资源紧张团队可能拖延适配
- **可能的兜底**：媒体推测最坏情况下，苹果会在 iOS 28 加回 iPad 应用兼容模式，以改善首发体验
- **对 App 生成器平台的影响**：生成模板应以 iOS 27.1 SDK 为基线、全面采用标准容器 + size class 布局，并内置 `windowScene.screen` 替代 `UIScreen.main` 的代码规范

---

## 七、建议行动清单

| 优先级 | 行动 | 时间 |
|---|---|---|
| P0 | 下载 Xcode 27.1 beta，手动安装 27.1 runtime，用 Device Hub 模拟器跑现有 App 排查布局 | 立即 |
| P0 | 代码审查三类高危点：`UIScreen.main` 引用、固定宽高布局、自定义导航/标签栏 | 立即 |
| P1 | 以 iOS 27.0 SDK 重编译完成基础适配（消除黑边） | 10 月 23 日发售前 |
| P1 | 采用标准容器 + size class 重构布局，按需接入竖排侧边栏与新 API | Q4 2026 |
| P0 | 完成全部适配——此后 App Store 不再接受 iOS 26 SDK 构建 | **2027 年 4 月前（死线）** |

官方参考 Tech Talks：

- [111461 Prepare your app for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111461/)
- [111462 Raise the bar with iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111462)
- [111463 Strike a pose with adaptive layouts on iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111463/)
- [111464 Leverage multiple displays and scenes on iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111464/)
- [111466 Design for iPhone Duo（HIG）](https://developer.apple.com/videos/play/tech-talks/111466)

---

## 附录：信息来源与交叉验证

- [Apple 中国官网新闻稿《Apple 发布 iPhone Duo》](https://www.apple.com.cn/newsroom/2026/09/apple-unveils-iphone-duo/)——硬件参数、发售时间
- Apple Developer Tech Talks 111461 / 111462 / 111463 / 111464 / 111466——SDK 行为、API、布局准则（一手来源）
- [DevelopersIO《By when do we need to support iPhone Duo?》](https://dev.classmethod.jp/en/articles/iphone-duo-compatible)——SDK 分级行为与 2027 年 4 月死线
- [Tech4K](https://tech4k.net/news/apple-releases-xcode-27-1-beta-with-iphone-duo-development-support-1u9h19e) / [iThinkDifferent](https://www.ithinkdiff.com/developers-can-now-test-apps-on-a-virtual-iphone-duo-before-it-ships/)——Xcode 27.1 beta、模拟器发布时间、Component 手动下载问题
- [The Mac Observer](https://www.macobserver.com/news/iphone-duo-new-apis-developers-have-not-used-before/)——六个独有 API 汇总、姿态与设计规则分析
- CNMO / [科创板日报](https://m.chinastarmarket.cn/detail/2394830) / [Cult of Mac](https://www.cultofmac.com/news/what-to-expect-in-ios-27)——iOS 27 特性、折叠适配代码线索、行业风险观点
- [Impress Watch](https://www.watch.impress.co.jp/docs/news/2139678.html) / 京东 / 天猫——价格与硬件规格三方印证
