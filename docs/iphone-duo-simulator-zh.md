# iPhone Duo 模拟器：测试并优化你的 SwiftUI 应用

> 原文：[iPhone Duo Simulator: Testing and optimizing your SwiftUI app](https://www.avanderlee.com/swiftui/iphone-duo-simulator/)
> 作者：Antoine van der Lee（SwiftLee）· 发布于 2026 年 9 月 22 日 · 阅读约 11 分钟
> 本文件为全文中文翻译，代码与专有名词保留英文。

iPhone Duo 一经发布，我们就都在等 Xcode 里的 iPhone Duo 模拟器。我们最终在 Xcode 27.1 的首个 beta 中拿到了它。这个模拟器与众不同，探索起来非常有趣——你可以把设备折叠成不同的角度，同时观察你的应用如何自适应。

不过，这也意味着我们要针对不同的显示尺寸和姿态（pose）调整应用。你可以从让应用正确伸缩（resize）开始，也可以更进一步，利用 iPhone Duo 独有的设备能力。在本文中，我会帮你把应用优化到你想要的程度。

[在真实 Apple Silicon 上用 Xcode 运行云端 Agent](https://xcloud.me/?utm_source=swiftlee&utm_medium=web&utm_campaign=xcloud) Xcloud 为你的云端 Agent 提供独立的 macOS 环境，包含你的 Xcode 版本、SDK 与依赖。它们可以在 Xcloud 接管基础设施的同时，编辑、构建并测试 iOS 或 macOS 应用。[了解更多](https://xcloud.me/?utm_source=swiftlee&utm_medium=web&utm_campaign=xcloud)。

---

## 本文内容

- [如何安装 iPhone Duo 模拟器](#如何安装-iphone-duo-模拟器)
- [让应用可伸缩以适配 iPhone Duo](#让应用可伸缩以适配-iphone-duo)
- [在不同 iPhone Duo 姿态下测试应用](#在不同-iphone-duo-姿态下测试应用)
- [用 ArrangementView 创建自适应布局](#用-arrangementview-创建自适应布局)
- [用保留区域（reserved regions）避开折叠处](#用保留区域reserved-regions避开折叠处)
- [响应铰链变化](#响应铰链变化)
- [为 iPhone Duo 适配工具栏](#为-iphone-duo-适配工具栏)
- [理解模拟器的局限性](#理解模拟器的局限性)
- [用 SwiftUI Agent Skill 审查 iPhone Duo 支持情况](#用-swiftui-agent-skill-审查-iphone-duo-支持情况)

---

## 如何安装 iPhone Duo 模拟器

下方是处于半折叠状态的 iPhone Duo 模拟器（位于 Device Hub 内）。

要开始在 iPhone Duo 模拟器上测试你的应用，你需要下载 **Xcode 27.1**。注意仅仅下载可能还不够——有用户反馈他们必须进入 **设置 → 组件（Settings → Components）**，点击 iOS 27.1 旁边的「更新（Update）」按钮。

安装完成后，iPhone Duo 会像其他任何目标设备一样出现，你可以直接在上面构建并运行应用。底部有新的工具栏按钮，可以让你折叠或展开设备。

按住 **Option ⌥** 会显示一个滑块，你可以用它精确控制设备的铰链角度（hinge angle）：

> 在 Device Hub 的 iPhone Duo 模拟器中，按住 Option 点击姿态按钮，即可控制那段漂亮的动画 🤩 pic.twitter.com/78nJ7vyZPC — Antoine v.d. SwiftLee  (@twannl) 2026 年 9 月 18 日

---

## 让应用可伸缩以适配 iPhone Duo

让应用可伸缩，是支持 iPhone Duo 的第一步。该设备**并不提供单一的固定画布**：你的应用可以在外屏与内屏之间移动、旋转、进入分屏（Split View），或在设备开合时改变尺寸。

你的布局应当**响应可用空间**，而不是去判断它是否运行在 iPhone Duo 上。避免基于设备标识符、方向（orientation）或固定屏幕宽度来做决定——一旦应用切换到另一块屏幕，或与其他应用共享屏幕，这些判断会迅速失效。让应用可伸缩，还能让你在 Apple Silicon Mac 上运行时也受益。

SwiftUI 的系统容器已经处理了诸多此类切换。例如，当空间充足时，`NavigationSplitView` 可以呈现多列，并在较小屏幕上自适应其呈现方式：

```swift
struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            DetailView()
        }
    }
}
```

当你的内容可以在水平与垂直排布之间切换时，可以使用 `ViewThatFits`：

```swift
struct AdaptiveContentView: View {
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                PreviewView()
                ControlsView()
            }

            VStack {
                PreviewView()
                ControlsView()
            }
        }
    }
}
```

这种做法并非 iPhone Duo 专属——而恰恰是它价值所在。同一套布局在分屏、iPad、可伸缩窗口，以及未来不同尺寸的设备上都能继续工作。

你还应当避免使用 `UIScreen.main.bounds` 来决定布局。iPhone Duo 有多块屏幕，"主屏"这一概念变得模糊。优先使用 SwiftUI 通过布局系统、环境值（environment values）和容器视图所提供的空间。

最后，确保你的内容尊重安全区域（safe areas）和布局边距（layout margins）。在不同活动屏幕、设备姿态和垂直工具栏位置下，内边距（insets）可能是不对称的。系统容器会自动处理这些区域，而自定义布局则需要额外留意。

一旦你的应用能正确伸缩，你就已经建立了基本的 iPhone Duo 支持。下一步是测试每个功能在不同屏幕与姿态下是否始终可访问。

---

## 在不同 iPhone Duo 姿态下测试应用

仅仅在内屏上跑一次应用，并不足以确认对 iPhone Duo 的支持。真正的考验在于：当可用空间变化时，你的界面是否依然可用。

先在外屏上打开应用，并深入导航好几层。打开一个 sheet、选中一项、滚动列表，或在表单中输入文字。然后**在应用仍在运行时展开设备**，确认其状态保持完好。你基本上要对每个界面都这样做，因为用户也可能这么操作。

我建议至少测试以下场景：

- 在外屏上启动应用。
- 从外屏移动到内屏。
- 在应用运行时折叠 / 展开设备。
- 在不同的铰链角度处暂停。
- **在折叠态和展开态下都旋转设备。**
- 在分屏（Split View）中与其他应用并排使用你的应用。
- 呈现 sheet、alert、菜单和键盘。
- 确认滚动内容与控件始终可访问。
- 确认导航与选中状态被保留。

要特别留意自定义布局。一个在设备完全展开时看起来正确的视图，在半闭合时可能把内容放到折叠处下方。固定 frame 可能开始被裁切，而浮层（overlay）和悬浮按钮可能落到可用空间之外。

安全区域的值在屏幕两侧也可能不同。不要假设 leading 和 trailing 的内边距相等。活动摄像头、折叠处、工具栏位置以及屏幕配置，都可能影响应用可用的空间。

最有价值的测试，是在与应用交互的过程中改变设备姿态。静态截图可以确认最终布局，但它们无法暴露状态丢失、动画中断，或视图短暂跳到错误位置的问题。如果你的应用在跨越这些过渡时始终保持可用，那你已经提供了扎实的基础支持。然后你可以决定哪些特定界面值得用新的 iPhone Duo API 来围绕折叠处调整内容。

---

## 用 ArrangementView 创建自适应布局

让应用可伸缩能确保它保持功能可用，但有些界面可以把两个可用区域**独立对待**而获益。Apple 在 **iOS 27.1** 中引入了 `ArrangementView`，用于包含主视图（primary）和次视图（secondary）的布局。

视频播放器就是一个好例子。视频与其播放列表彼此相关，但它们不必始终维持同一固定排列。当水平空间充足时可以让它们并排显示，并在其他配置下让系统找到更合适的排列：

```swift
struct AdaptivePlayerView: View {
    var body: some View {
        if #available(iOS 27.1, *) {
            ArrangementView {
                PlayerView()
            } secondary: {
                PlaylistView()
            }
            .arrangementViewStyle(.split)
        } else {
            ViewThatFits {
                HStack {
                    PlayerView()
                    PlaylistView()
                }

                VStack {
                    PlayerView()
                    PlaylistView()
                }
            }
        }
    }
}
```

`.split` 样式在两个区域都应保持可见、且互不遮挡时表现良好。可以想到视频与其控件、编辑器与其检查器（inspector），或文档与其辅助信息。

当允许次视图出现在主内容之上时，可以使用 `.overlay` 样式：

```swift
.arrangementViewStyle(.overlay)
```

并非每个双列界面都需要 `ArrangementView`。像 `NavigationSplitView`、`TabView`、`List`、`ScrollView` 这样的 SwiftUI 容器已经能自适应可用空间。只有当你的界面包含两个自定义区域、且当前需要用 `HStack`、`VStack` 或 `ZStack` 才能正确摆放时，我才引入 Arrangement。

例如，我在我的 [Video Compression 应用](https://www.videocompression.app) 中更新了一个引导（onboarding）界面，调整了顺序，把存储示例显示在顶部而非中间：

> （文中配图：使用 arranged view 前后的 iPhone Duo 设计对比）

你的应用可能要支持 iOS 27.1 之前的版本，因此即便无法使用 `ArrangementView`，也要确保两个区域仍然可用。Apple 在 [Strike a pose with adaptive layouts on iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111463/) 中展示了更多排列模式。

---

## 用保留区域（reserved regions）避开折叠处

系统容器会自动处理大多数硬件区域。然而，一个自定义的、铺满边缘（edge-to-edge）的界面，仍可能把重要控件放在折叠处或摄像头下方。

SwiftUI 将这些区域表示为**保留区域（reserved regions）**。你可以通过 `GeometryProxy` 查询它们：

```swift
GeometryReader { proxy in
    let divisions = proxy.reservedRegions(kind: .division)
    let occlusions = proxy.reservedRegions(kind: .occlusion)

    CustomCanvas(
        divisionFrames: divisions.map(\.frame),
        occlusionFrames: occlusions.map(\.frame)
    )
}
```

**division（分隔区）** 将你的界面分成多个可用区域。内屏上活动的折叠处（fold）就是一个 division 的例子。你可以用它的 frame 来移动或缩放一组连贯的视图，而不是让内容横跨折叠处。

**occlusion（遮挡区）** 覆盖可用空间中较小的一部分。内屏摄像头就是一例：内容可以继续环绕它，但重要的控件和信息应当留在其 frame 之外。

每个保留区域都提供 `frame`、`margins` 和 `isActive` 状态。查询默认只返回活动区域，这通常正是你想要的。当你要做更高层的布局决策时，可以包含非活动区域：

```swift
let possibleDivisions = proxy.reservedRegions(
    kind: .division,
    options: .includeInactive
)
```

非活动区域当前并不阻碍你的界面，可能返回一个零尺寸的 frame。在围绕它移动内容之前，务必先检查 `isActive`。

我建议仅在确认标准 SwiftUI 容器无法解决问题后，才去查询保留区域。像 `List`、`ScrollView`、sheet、alert 或导航容器，已经能围绕折叠处和系统界面自适应。手动挪动它们的内容，反而会让过渡显得不自然。

保留区域对自定义画布、游戏、媒体界面或手动定位的控件最有价值。移动幅度要小，并保留相关元素之间的关系。你的界面应当让人感觉是"同一屏幕在自适应"，而不是"每个姿态都蹦出一个完全不同的布局"。

注意，所有这些 API 都需要 **iOS 27.1**。把现有的自适应布局作为更早版本的回退方案，把保留区域当作增强而非基础支持的硬性要求。这真的是画龙点睛（putting the dots on the i）！你可以从 Apple 的 [Preparing your app for iPhone Duo](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo) 文档中了解更多。

---

## 响应铰链变化

铰链提供的，远不止一处需要避开的折叠。你可以利用它的角度，创造出在设备开合时响应的交互或视觉效果。

SwiftUI 提供了 `onHingeChange` 修饰符来观察当前的铰链上下文（hinge context）。下面的例子根据折叠角度对画面（artwork）做了轻微缩放：

```swift
@available(iOS 27.1, *)
struct HingeReactiveArtwork: View {
    @State private var foldEffect = 0.0

    var body: some View {
        ArtworkView()
            .scaleEffect(1 + foldEffect * 0.04)
            .onHingeChange { _, context in
                if let hinge = context.hinge,
                   hinge.status == .partiallyOpen {
                    foldEffect = min(
                        max(hinge.angle.degrees / 180, 0),
                        1
                    )
                } else {
                    foldEffect = 0
                }
            }
    }
}
```

铰链是可选值（optional），因为当前设备或屏幕配置可能并没有铰链。当铰链不可用时重置效果，可以防止你的界面卡在中间状态。

我建议**仅把铰链变化用于可选的增强**。例子包括：调整一段动画、改变画面的透视、控制某个交互，或根据折叠角度影响音频。

**不要用原始的铰链角度来决定你的布局。** 它的更新频率和精度，并非为定位关键界面元素而设计。布局决策应当改用尺寸类别（size classes）、`ArrangementView` 和保留区域。显然，你也要保证在没有铰链时该功能依然可用。本例中的画面即便没有缩放效果也能正常工作，从而让同一个视图能运行在更老的 iPhone 和更早的系统上。

在可用性检查（availability check）之后选择铰链感知视图，并提供常规回退：

```swift
if #available(iOS 27.1, *) {
    HingeReactiveArtwork()
} else {
    ArtworkView()
}
```

Apple 在 [Leverage multiple displays and scenes on iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111464/) 中展示了更多有创意的铰链交互，你也可以[在此了解更多关于可用性检查的内容](https://www.avanderlee.com/swift/available-deprecated-renamed/)。

---

## 为 iPhone Duo 适配工具栏

在 iPhone Duo 上，工具栏可以**垂直显示**，为内容保留更多空间。当你把工具栏项挂到系统容器（如 `NavigationStack`、`NavigationSplitView`、`TabView`）上时，SwiftUI 会自动处理这件事。

确保每个工具栏操作**同时提供标题和图标**：

```swift
struct PhotoEditorView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        PhotoCanvasView()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarPinnedTrailing) {
                    Button("Export", systemImage: "square.and.arrow.up") {
                        exportPhoto()
                    }
                }
            }
    }

    private func exportPhoto() {
        // 导出编辑后的照片
    }
}
```

即便 SwiftUI 只显示符号（symbol），标题依然重要。系统会把它用于无障碍、展开式呈现和溢出菜单。这一点在 iPhone Duo 到来之前就是如此。

**语义化位置（semantic placements）** 也有助于系统保持合理的顺序。取消（cancellation）和导航操作应靠近 leading 边缘，而重要操作可以使用 `.topBarPinnedTrailing`。避免基于物理边缘来摆放控件，因为工具栏可能随屏幕和当前配置而移动。再次强调，这些都是始终适用的通用原则。

SwiftUI 会根据工具栏项的内容来决定它能否放进垂直条。基于符号的控件通常会自动适配，而只有标题的按钮和复杂的自定义视图可能仍保持水平。

在需要时可以覆盖单个项的行为：

```swift
ToolbarItem {
    EditingModePicker()
}
.axisBehavior(.horizontalOnly)

ToolbarItem {
    CompactAdjustmentControl()
}
.axisBehavior(.verticalPreferred)
```

当某个控件无法提供有意义的垂直形态时，使用 `.horizontalOnly`。当你的自定义控件是紧凑设计、在两种方向都表现良好时，使用 `.verticalPreferred`。在大多数情况下，保留自动行为能得到最佳结果。

当自定义工具栏项需要调整呈现方式时，可以从环境中读取 `toolbarVerticalEdge`：

```swift
@Environment(\.toolbarVerticalEdge)
private var toolbarVerticalEdge
```

非 `nil` 值意味着当前环境在该边缘支持垂直工具栏。用它来选择一个紧凑形态，而不是手动添加安全区域间距。

大多数应用应当保留自动的垂直工具栏行为。你可以用 `.toolbarVerticalBehavior(.disabled)` 关闭它，但我只会在某个界面明显用水平控件更合适时才这么做，比如全屏视频播放器。

这些 API 都需要 **iOS 27.1**，并可以在 iPhone Duo 模拟器上测试。你现有的工具栏在更早的系统上仍是回退方案，使垂直行为成为一种渐进增强（progressive enhancement）。你可以阅读 [Raise the bar with iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111462/) 了解更多。

---

## 理解模拟器的局限性

iPhone Duo 模拟器非常适合测试布局、显示切换、安全区域、垂直工具栏，以及基于铰链角度的交互。但它**无法取代真机测试**。

摄像头工作流是最重要的局限。模拟器无法复现外屏、内屏、后置摄像头之间的切换。你也无法验证方向感知的摄像头选择，或在**外屏**显示内容的摄像头配件（是的，[我正在研究为 iPhone Duo 提供模拟器摄像头支持](https://www.rocketsim.app/docs/features/capturing/simulator-camera-support/?seg_id=01M37KHHSNJK1TSCXARS0EXZC6.19937.1790182999862)）。

测试仍然需要真机：

- 摄像头的选择与切换。
- 拍摄时在外屏上显示的内容。
- 半折叠姿态下的真实触摸可达性（reachability）。
- 触觉反馈（haptic feedback）与物理交互。
- 性能、内存占用与发热表现。
- 内容在真实折叠屏上的外观。

iPhone Duo 并不便宜，但 Apple 会举办若干研讨会，提供在真机上测试你应用的机会。老实说，大多数支持工作都可以在模拟器上可靠完成。我愿意把它类比于开发普通 iPhone 应用：你最终确实想在真机上测试，但在大多数情况下，你仅凭模拟器就能完成开发。

另请注意，Xcode 团队正在努力改进 Device Hub 和这款新模拟器。我确信未来 Xcode 版本会带来新功能，也请花时间提交你的反馈。他们很重视——已经修复了我提的好几个问题。

---

## 用 SwiftUI Agent Skill 审查 iPhone Duo 支持情况

你也可以用 AI agent 来审查你现有的 SwiftUI 视图对 iPhone Duo 的支持。我把 [SwiftUI Agent Skill 更新到了 5.1.0 版本](https://github.com/AvdLee/SwiftUI-Agent-Skill/releases/tag/5.1.0)，加入了针对可伸缩布局、保留区域、arrangement、铰链效果和垂直工具栏的专门指引。

例如，你可以在项目中使用如下提示词（prompt）：

```
Review this SwiftUI view for iPhone Duo support.

Check whether it:
- Resizes correctly between compact and regular environments.
- Uses system containers before custom layout logic.
- Respects asymmetric safe areas.
- Benefits from ArrangementView or reserved regions.
- Supports vertical toolbar placement.
- Preserves functionality across display and pose changes.
- Provides fallbacks for APIs requiring iOS 27.1.

Do not use device detection, orientation, or the raw hinge angle to drive layout.
```

这个 skill 能帮你的 agent 判断：某个视图是只需要通用的可伸缩性，还是能受益于某个新的 iOS 27.1 API。它还能防止常见错误，例如手动避开一个系统容器已经处理好的折叠处。

我倾向于一次审查一个界面。从你最重要的自定义布局开始，然后继续处理包含工具栏、媒体、画布或手动定位控件的界面。

agent 审查不能替代 iPhone Duo 模拟器测试。它可以指出可疑的布局决策并建议现代 API，但你仍然应当亲自把应用跑过不同的屏幕配置。

你可以在我的 [SwiftUI Agent Skill 文章](https://www.avanderlee.com/ai-development/swiftui-agent-skill-build-better-views-with-ai/) 中了解更多关于安装和使用该 skill 的内容。

---

## Apple 的 iPhone Duo 资源

Apple 提供了一个专门的 iPhone Duo 开发者中心，包含最新文档、视频、设计指引和 Xcode 要求。我建议从这些书面资源开始：

- **Preparing your app for iPhone Duo** 讲解技术基础，包括伸缩、保留区域、arrangement、工具栏和多屏显示。
- **Designing for iPhone Duo** 涵盖连续性（continuity）、可达性（reachability）、自适应布局，以及围绕折叠处的设计。

Apple 还发布了六个聚焦的 Tech Talk：

- **Prepare your app for iPhone Duo** 讲解支持该设备所需的最低工作量。
- **Raise the bar with iPhone Duo** 讲解垂直工具栏、标签栏（tab bar）和自适应控件。
- **Strike a pose with adaptive layouts on iPhone Duo** 介绍 arrangement 和保留区域。
- **Leverage multiple displays and scenes on iPhone Duo** 涵盖铰链交互、额外窗口和多屏内容。
- **Build a great camera experience for iPhone Duo** 讲解摄像头选择、方向变化和拍摄配件。
- **Design for iPhone Duo** 演示界面如何在适配设备不同姿态的同时保持熟悉感。

我会从"Prepare your app"和"Strike a pose"开始。两者合在一起，覆盖了可伸缩基础和大多数 SwiftUI 应用需要的新布局 API。之后你可以根据应用功能，继续观看工具栏、多屏、摄像头或设计相关的场次。

由于 iOS 27.1 SDK 仍处于 beta，**在 Apple 发布正式版时请重新查阅这些资源**。在 iPhone Duo 上市之前，API、模拟器局限性和推荐行为都可能发生变化。

---

## 结论

支持 iPhone Duo，始于让应用可伸缩。SwiftUI 的系统容器已经处理了诸多显示变化，让你能专注于测试：在不同姿态下，导航、控件和内容是否始终可访问。然后，你可以在那些确实能改善体验的地方，采用 `ArrangementView`、保留区域、垂直工具栏和铰链效果。这些 API 应当**增强**你现有的界面，而不是为每个设备配置都引入一个完全不同的应用。

iPhone Duo 模拟器让这个过程出奇地有趣。它让你在探索此前在 iPhone 上不可能实现的交互时，顺带发现布局问题。

如果你想进一步提升 SwiftUI 知识，欢迎查看 [SwiftUI 分类页面](https://www.avanderlee.com/swiftui/)。如果你有任何补充建议或反馈，随时联系我或在 [Twitter 上 @ 我](https://twitter.com/twannl)。

谢谢！

---

*翻译说明：本文为 SwiftLee 文章全文中文翻译。所有 Swift / SwiftUI 代码、API 名称、专有名词（如 `ArrangementView`、`reservedRegions`、`onHingeChange`）、链接均保留原文；代码注释与正文已译为中文。原文发布时 iOS 27.1 SDK 仍处于 beta，相关 API 可能在正式版中变动。*
