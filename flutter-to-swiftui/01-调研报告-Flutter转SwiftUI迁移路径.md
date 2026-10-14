# Flutter 源码 → SwiftUI iOS App：可行路径调研

> 调研日期：2026-10-14　|　目标：从 Flutter App 源码反推业务逻辑，再改写为原生 SwiftUI App

---

## 0. 一句话结论

**没有、也不可能有可靠的"一键 Flutter→SwiftUI 转译器"**（渲染模型根本不同：Flutter 自绘 Skia/Impeller，SwiftUI 走原生 UIKit 组件）。
业界的共识路径是 **两段式**：

```
① 静态+动态取证，把 Flutter 代码「读成一份规约」（不是当源码翻译）
② 抛开 Dart，按规约用 SwiftUI 从零重写
```

社区里已经有现成 Agent Skill 覆盖这两段，可直接组合使用，无需自己从零造。

---

## 1. 现成 Skill 盘点（GitHub）

### 1.1 分析段：把 Flutter 代码读成规约

| Skill / 工具 | 仓库 | 定位 | 成熟度 |
|---|---|---|---|
| **flutter-reverse-engineering** ⭐推荐 | `abhiabby3008/flutter-reverse-engineering-skill` | 21 阶段分析流水线，输出架构蓝图 + Mermaid 图 + 自动 CLAUDE.md | ★★★★☆ v1.1.0，9 stars，7 文件，SKILL.md 48.3KB |
| **flutter-mcp** | npm `@raheesahmed37/flutter-mcp` | MCP Server，5 个工具（get_project_info / get_repo_map / read_context / search_code / analyze_project），纯正则解析，**不需要 Dart SDK** | ★★★☆☆ 适合做常驻上下文源 |
| **llmifier** | `PhilippHGerber/llmifier` | Dart CLI，把整个 Flutter 工程压成单个 `llms.txt` / `llms-full.txt` 喂给 LLM | ★★★☆☆ 适合小中型项目一次性投喂 |

**flutter-reverse-engineering 的三种输入模式：**

| 模式 | 输入 | 适用 |
|---|---|---|
| Mode A | 源码目录（有 `pubspec.yaml` + `lib/`） | ✅ **本场景就是这个** |
| Mode B | `.apk` / `.xapk` 文件（挖 `libapp.so` 字符串） | 只有包没有源码时 |
| Mode C | USB/无线 ADB 直连手机拉包 | 竞品分析 |

**它的 21 个阶段（源码模式核心是 3–14）：**

| Phase | 产出 |
|---|---|
| 3 项目身份 | 名称/版本/SDK 约束/Flutter channel/是否 monorepo |
| 4 依赖分析 | 16 大类、识别 100+ 常见包（如 `razorpay_flutter` = 印度市场App） |
| 5 架构识别 | Provider / BLoC / Riverpod / GetX / Clean / MVVM / MVC / Feature-First，**读实际代码确认而非只看目录名** |
| 6 目录结构 | 带注解的 `lib/` 完整树 + 文件计数 |
| 7 状态管理深挖 | provider/bloc 清单、注入点、UI 消费方式、持久化、横切状态 |
| 8 领域知识 | 数据模型、API 契约（端点/鉴权/错误处理）、实体关系、枚举常量 |
| 9 导航路由 | GoRouter/AutoRoute/GetX/Navigator 1.0&2.0 识别、路由表、守卫、深链、Tab 结构 |
| 10 服务层 | 服务清单、单例/实例模式、依赖、关键方法 |
| 11 设计模式 | 单例/仓储/工厂/观察者/DI/mixin/extension + 文件位置 |
| 12 构建配置 | 平台、min SDK、权限、CI/CD、flavors、Shorebird OTA、签名 |
| 13 代码质量 | lint、测试覆盖、空安全、模型类型化、错误处理一致性 |
| 14 功能与页面地图 | 面向用户的特性树 + 导航入口 |

输出文件：`ARCHITECTURE_BLUEPRINT.md`（15 章 + 3 附录 + 内联 Mermaid）、`architecture_report.html`（可搜索/可折叠/暗亮双模的交互面板）、`CLAUDE.md`。

### 1.2 改写段：Dart → Swift / SwiftUI

| Skill | 仓库 | 覆盖映射 |
|---|---|---|
| **flutter-sdk-to-swift** ⭐必装 | `OMIXEC/Mobile-dev-skills/tree/main/skills/flutter-sdk-to-swift` | Riverpod→Combine、GoRouter→SwiftUI Navigation、Dio→URLSession、Hive/SQLite→Core Data、Widget→SwiftUI |
| **ios-swift-development** | 同上仓库 | 原生 iOS：SwiftUI / Combine / MVVM / Core Data |
| **swiftui-expert-skill** | `deonmenezes/mobile-app-skill` | SwiftUI 状态管理、视图组合、布局、性能、动画、API 迁移、Instruments 调试；含 `references/latest-apis.md`（过时 API 替换）、`soft-deprecation.md`、`liquid-glass.md`、`image-optimization.md`、`trace-recording.md` |
| liquid-glass-design | 同上仓库 + OMIXEC 仓库均有 | iOS 26 Liquid Glass 设计规范 |

> ⚠️ **质量提醒**：`OMIXEC/Mobile-dev-skills` 只有 **1 star**，最后推送 2026-08-06，且其 README 示例里把 `setState`/`_count` 写进了 `StatelessWidget`（明显的低级错误）。它的**映射表可以直接抄，但不要迷信它的输出，必须人工/编译校验**。

### 1.3 安装命令

```bash
# 改写段（推荐，只装需要的 skill）
npx skills add omixec/Mobile-dev-skills --skill flutter-sdk-to-swift -g
npx skills add omixec/Mobile-dev-skills --skill ios-swift-development -g

# 分析段
# 方式 A：走 Claude Code 插件市场
claude plugin marketplace add abhiabby3008/flutter-reverse-engineering-skill
claude plugin install flutter-reverse-engineering

# 方式 B：git clone 后手工放进 ~/.claude/skills/
git clone https://github.com/abhiabby3008/flutter-reverse-engineering-skill.git
cp -r flutter-reverse-engineering-skill/plugins/flutter-reverse-engineering ~/.claude/skills/

# 方式 C：MCP（给任意 Agent 常驻上下文能力）
npm install -g @raheesahmed37/flutter-mcp
```

---

## 2. 完整工作流（可执行版）

### 阶段 0 — 前置体检（决定工期是 2 周还是 2 个月）

先扫一遍"**没有干净原生映射**"的东西，这些是工期杀手：

| 高危项 | 说明 | 兜底方案 |
|---|---|---|
| `CustomPainter` / `CustomClipper` | 自绘路径 | SwiftUI `Canvas` / `Path` 或 `CAShapeLayer` |
| `BackdropFilter` / `ShaderMask` | 模糊/着色器 | `.background(.ultraThinMaterial)` / Metal |
| Platform Channel / FFI 插件 | 每个都是手写的原生钩子 | 逐个重写，别猜 |
| 三方广告 / 推送 / 地图 / 支付 SDK | Flutter 版 ≠ iOS 版 | 找同名 iOS SDK，通常有 |
| Firebase Crashlytics / 动态化 | — | 官方 iOS SDK |
| Shorebird / CodePush OTA | iOS 上 App Store 不允许代码热更 | 直接砍掉 |

### 阶段 1 — 静态扫描（Inventory）

产出 `CONVERSION_PLAN.md`，必含：

1. `pubspec.yaml`：依赖、Flutter SDK 约束、assets、fonts
2. `lib/` 完整树：每个 screen / route 及其用途
3. 状态管理方案：Provider / Riverpod / Bloc / GetX / setState
4. 数据层：HTTP client、本地 DB（sqflite / Hive / Isar）、shared_prefs
5. Platform channels 与原生插件，**逐条列出**
6. 主题、字体、颜色 token、国际化字符串

> 提示词模板：
> `读这份 Flutter 仓库，在 ../native-output/ 写 CONVERSION_PLAN.md，按上面 6 项汇总。先别动代码，生成计划后停下。`

### 阶段 2 — 行为取证（补静态看不到的）

静态代码只能告诉你"写了什么"，运行时才知道"实际怎么跑"。三种取证手段：

| 手段 | 拿什么 | 怎么做 |
|---|---|---|
| **抓包** | 真实 API 契约、字段、鉴权 | Charles / Proxyman / mitmproxy（注意 SSL pinning） |
| **UI 走查** | 页面流转、动画、边界态 | 逐屏截图 / 录屏，建立屏幕清单 |
| **路由表 dump** | 完整路由与参数 | 搜 `GoRouter(` / `routes:` / `Navigator.pushNamed`，或直接跑 `flutter_reverse` 类工具 |

### 阶段 3 — 蓝图规约（这是真正的"需求文档"）

把上面产物固化成一份 **与语言无关** 的规约，格式建议：

```
AppSpec/
├── 00-overview.md         # App 干嘛的、目标平台、iOS 最低版本
├── 01-screens/            # 每屏一个文件：布局意图 / 数据来源 / 交互 / 空态错误态
├── 02-navigation.md       # 页面流转图（Mermaid）+ 深链 + Tab 结构
├── 03-state.md            # 每个状态：归属、生命周期、持久化与否、订阅方
├── 04-api/                # 接口契约：URL / method / request / response / 错误码
├── 05-models.md           # 实体 + 关系（ER 图）
├── 06-persistence.md      # 本地存储方案与迁移
├── 07-design-tokens.md    # 颜色/字号/间距/圆角/图标/动效
├── 08-platform-hooks.md   # 原生能力清单（相机/定位/推送/生物识别/Keychain）
└── 09-parity-checklist.md # 验收对照表
```

> **关键**：SwiftUI 重写时，只对着这份规约写，**不再看 Dart 代码**。这是避免产出"Flutter 味原生代码"的唯一办法。

### 阶段 4 — SwiftUI 实现

- **先定架构再写码**：导航用 `NavigationStack` + `NavigationPath`；状态优先 iOS 17+ 的 `@Observable` + `@Environment`（比 `ObservableObject` 更细粒度，减少无效重绘）；网络 `URLSession` + `async/await`；持久化 `SwiftData`（iOS 17+）或 `GRDB`。
- **自底向上**：Models/API → Services/Repositories → ViewModels → Views。
- **逐屏验收**：每完成一屏，对照 `09-parity-checklist.md` 打勾。

---

## 3. Dart → Swift 映射速查表

### 3.1 类型

| Dart | Swift |
|---|---|
| `String` / `int` / `double` / `bool` | `String` / `Int` / `Double` / `Bool` |
| `List<T>` / `Map<K,V>` | `[T]` / `[K: V]` |
| `T?` | `T?` |
| `enum` | `enum` |
| `class`（不可变） | `struct` |
| `abstract class` | `protocol` |
| `mixin` | `protocol` + extension 默认实现 |
| `Future<T>` | `async throws -> T` |
| `Stream<T>` | `AsyncStream<T>` / Combine `Publisher` |

### 3.2 状态管理

| Flutter | SwiftUI |
|---|---|
| `setState` | `@State` |
| `Provider` / `ChangeNotifier` | `@Observable` + `@Environment` |
| `Riverpod StateNotifier` + `AsyncValue` | `@Observable ViewModel` + `enum LoadState<T>` |
| `Bloc` / `Cubit` | `@Observable` + `Reducer` 风格 或 TCA |
| `InheritedWidget` | `@Environment` / `EnvironmentKey` |
| `StreamBuilder` | `.task {}` + `AsyncStream` |
| `FutureBuilder` | `.task {}` + `@State` 加载态 |
| `ValueNotifier` | `@Observable` / `CurrentValueSubject` |

### 3.3 布局 & 组件

| Flutter | SwiftUI |
|---|---|
| `Column` / `Row` / `Stack` | `VStack` / `HStack` / `ZStack` |
| `Container`(padding+decoration) | `.padding()` + `.background()` + `.overlay()` 拆开 |
| `ListView` / `GridView` | `List` / `LazyVGrid` |
| `SingleChildScrollView` | `ScrollView` |
| `Expanded` / `Flexible` | `.frame(maxWidth:)` / `Spacer()` / `ViewThatFits` |
| `Padding` / `SizedBox` / `Center` | `.padding()` / `.frame()` / 容器默认居中 |
| `Scaffold` + `AppBar` | `NavigationStack` + `.navigationTitle()` |
| `BottomNavigationBar` | `TabView` |
| `Card` | `.background(.regularMaterial, in: .rect(cornerRadius:))` |
| `showDialog` / `showModalBottomSheet` | `.sheet()` / `.alert()` / `.fullScreenCover()` |
| `SnackBar` | 自定义 toast overlay |
| `TextFormField` | `TextField` + `.textFieldStyle()` |
| `RefreshIndicator` | `.refreshable {}` |
| `Hero` 动画 | `.matchedGeometryEffect()` / `navigationTransition` |
| `Navigator.push` | `navigationPath.append(value)` |
| `CircularProgressIndicator` | `ProgressView()` |
| `Image.network` | `AsyncImage` |

### 3.4 网络 & 持久化

| Flutter | SwiftUI |
|---|---|
| `Dio` | `URLSession` + `async/await`（或 Alamofire） |
| `http` | `URLSession.shared.data(for:)` |
| `json_serializable` | `Codable` |
| `freezed` | `struct` + `enum`（或 swift-macro） |
| `shared_preferences` | `UserDefaults` / `@AppStorage` |
| `Hive` / `Isar` | `SwiftData` / `GRDB` |
| `sqflite` | `GRDB` / `SQLite.swift` |
| `flutter_secure_storage` | `Keychain`（`SecItem`） |
| `connectivity_plus` | `NWPathMonitor` |
| `flutter_local_notifications` | `UserNotifications` |
| `permission_handler` | 各框架原生 API |

---

## 4. 三种路线对比（按项目规模选）

| 路线 | 适用 | 工期 | 风险 |
|---|---|---|---|
| **A. Skill 组合（推荐）**<br>flutter-reverse-engineering + flutter-sdk-to-swift | 中小 App（<50 屏），逻辑清晰 | 短 | 中：需逐屏人工校验 |
| **B. MCP 常驻上下文**<br>flutter-mcp 挂到 Agent | 大型仓库，需要反复查询 | 中 | 低：人一直在环 |
| **C. 手工 Spec-First**<br>只抄映射表，规约自己写 | 大型 / 高合规 App | 长 | 最低 |

---

## 5. 建议的下一步

1. **先确认目标 App 的 Flutter 源码在哪**（本地路径 / GitHub 仓库）。
2. 装 skill：`flutter-reverse-engineering`（分析）+ `flutter-sdk-to-swift`（改写）。
3. 跑一遍 Mode A 分析，先只看 `ARCHITECTURE_BLUEPRINT.md` 的 Phase 12（构建配置）和 gotchas 清单，估工期。
4. 再决定是否全量重写。

---

## 附：参考链接

- https://github.com/abhiabby3008/flutter-reverse-engineering-skill （分析，9 stars，v1.1.0）
- https://github.com/OMIXEC/Mobile-dev-skills （改写，28 skills，1 star）
- https://github.com/deonmenezes/mobile-app-skill （SwiftUI 专家）
- https://www.npmjs.com/package/@raheesahmed37/flutter-mcp （MCP Server）
- https://github.com/PhilippHGerber/llmifier （Dart→LLM 上下文）
- https://lingcode.dev/tutorials/migrate-a-flutter-app-to-native-with-lingcode.html （五阶段迁移方法论，印证"translate-don't-port"）
