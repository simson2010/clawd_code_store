# 跨 Framework 触发 UIScene 切换 —— 架构设计文档

## 1. 背景与项目约束

本仓库讨论的 iOS App 由多个**独立开发的 Framework** 组成。跨 Framework 通信遵循以下硬性约束（Eric 项目规则）：

- **Redux 仅在单个 Framework 内部使用；跨 Framework 通信禁止使用。** 原因：各 Framework 独立编译，运行时通过 `NSClassFromString` 提取类名并初始化，**不存在跨 Framework 的统一内存句柄**（无共享单例 / 共享 store）。
- 认可的跨 Framework 解耦通道：**URL Scheme / Universal Link (`openURL`)**。
- **场景切换必须由主 App (AppDelegate / SceneDelegate) 主导**；功能 Framework **不得自行创建 UIWindow 或挂载 rootViewController**。

本文回答一个问题：在以上约束下，当一个功能 Framework 需要触发主 App 切换（或新建）一个 UIScene 时，如何**避免竞态**——即功能 Framework 发出切换请求后，不因主 App 尚未就绪就提前渲染自己的 View/VC。

## 2. 为什么 Notification / Redux 不适合跨 Framework

| 方案 | 问题 |
|---|---|
| `NotificationCenter` | 需要双方引用同一 `Notification.Name`；本质是进程内广播，跨独立 Framework 时命名/生命周期耦合，且无法携带"由谁提供内容"的类型信息 |
| `Redux EventBus / Store` | 需要跨 Framework 共享 store 实例，**直接违反"无统一内存句柄"约束** |
| 共享 Coordinator 单例 | 同样需要跨 Framework 共享实例，被禁止 |

> 注：以上方案在"同进程、有共享句柄"的普通 App 中完全可用，仅在本文约束下不适用。

## 3. URL Scheme 能同步通知 AppDelegate 吗？——不能

`UIApplication.shared.open(_:options:completionHandler:)` 是**异步系统调用**。从功能 Framework 发出到主 App `application(_:open:options:)` 回调，中间经过 SpringBoard / URL routing 调度，**延迟不可控**（几毫秒到更长，锁屏或后台时更久）。它设计上就是跨进程异步，没有同步语义，也无法"等 AppDelegate 处理完再返回"。

**结论：URL Scheme 的异步触发延迟是存在的、绕不开的。** 但关键要分清——

> **异步的是"触发"，不是"渲染"。**

## 4. 竞态根因：不是 URL Scheme，而是"功能 Framework 自己渲染"

典型错误时序：

```
功能 Framework: openURL("myapp://scene/secondary")
             → 不等 AppDelegate，直接 window.rootViewController = FeatureVC  ← 竞态!
主 App:       application(_:open:) 收到
             → requestSceneSessionActivation(...)
             → 系统创建 Scene → willConnectTo（此时 window 才就绪）
```

在 multi-scene 下每个 Scene 有独立 `UIWindow`，不存在全局 `keyWindow`。功能 Framework 主动碰 window 既错又竞态。

## 5. 正确解法：主 App 拉取模式（URL Scheme 只传意图）

把方向反过来：**功能 Framework 只"被询问时提供 VC"，渲染由主 App 在场景就绪后驱动。**

数据流：

```
功能 Framework ──openURL(意图+入口类名)──▶ AppDelegate.application(_:open:)
        (异步, 仅路由)                          │ requestSceneSessionActivation
                                               ▼
                                        系统创建 Scene
                                               │ willConnectTo (window 就绪)
                                               ▼
                               NSClassFromString(入口类名) + 协议 → 同步拉取 VC → 挂 window
```

### 5.1 约定协议（双方各自声明同签名，不共享内存）

```swift
@objc protocol SceneContentProviding: NSObjectProtocol {
    static func makeRootViewController() -> UIViewController
}
```

### 5.2 功能 Framework 入口类

独立编译，只产出 VC，不碰 window、不 import 主 App：

```swift
@objc final class FeatureXEntry: NSObject, SceneContentProviding {
    static func makeRootViewController() -> UIViewController {
        return FeatureXViewController()
    }
}
```

### 5.3 功能 Framework 只发"意图"

无主 App 句柄，只能 `openURL`：

```swift
let url = URL(string: "myapp://scene/secondary?feature=FeatureXEntry")!
UIApplication.shared.open(url, options: [:])
```

### 5.4 主 App 接收（异步，但只做路由，不渲染）

```swift
func application(_ app: UIApplication,
                 open url: URL,
                 options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    guard url.host == "scene",
          url.pathComponents.contains("secondary"),
          let feature = URLComponents(url: url, resolvingAgainstBaseURL: false)?
              .queryItems?.first(where: { $0.name == "feature" })?.value
    else { return false }

    let activity = NSUserActivity(activityType: "com.demo.secondaryScene")
    activity.userInfo = ["featureClass": feature]   // 把入口类名带进场景
    UIApplication.shared.requestSceneSessionActivation(
        nil, userActivity: activity, options: nil, errorHandler: nil)
    return true
}
```

### 5.5 主 App 在场景就绪后同步拉取（竞态消失的关键）

```swift
func scene(_ scene: UIScene,
           willConnectTo session: UISceneSession,
           options connectionOptions: UIScene.ConnectionOptions) {
    guard let windowScene = scene as? UIWindowScene else { return }
    let window = UIWindow(windowScene: windowScene)   // window 已就绪

    let activity = connectionOptions.userActivities.first
                  ?? session.stateRestorationActivity
    if let cls = NSClassFromString(activity?.userInfo?["featureClass"] as? String ?? "")
              as? SceneContentProviding.Type {
        window.rootViewController = cls.makeRootViewController()  // 同步、在正确 window 上
    } else {
        window.rootViewController = MainViewController()
    }
    window.makeKeyAndVisible()
}
```

## 6. 约束满足对照

| 项目约束 | 如何满足 |
|---|---|
| 不共享统一内存句柄 | 靠 `NSClassFromString` + 协议名约定，双方零共享实例 |
| 不用 Redux 跨 Framework | 全程无 store |
| 功能 Framework 独立开发 | 框架只写 `FeatureXEntry` + `makeRootViewController`，不 import 主 App |
| 不要提前渲染竞态 | 渲染发生在 `willConnectTo` 之后，window 已存在，完全同步 |

## 7. 备选：启动期类扫描注册表（进一步压低触发延迟）

若希望 URL Scheme 只传短 key（而非完整类名），可让**主 App 启动时主动扫描入口类**建本地注册表：

```swift
// 主 App 进程内，不违反"不共享句柄"约束
var registry: [String: SceneContentProviding.Type] = [:]

func scanFeatureEntries() {
    var count: CUnsignedInt = 0
    let classes = objc_copyClassList(&count)!
    for i in 0..<Int(count) {
        let cls: AnyClass = classes[i]
        if let provider = cls as? SceneContentProviding.Type {
            let name = String(cString: class_getName(cls))
            registry[name] = provider
        }
    }
    free(UnsafeMutableRawPointer(classes))
}
```

功能 Framework 仍传入口类名作为 key，主 App 启动时一次性发现并建表，运行时查表即可。仅当 Framework 列表为插件式、需要解耦"主 App 预先硬编码类名"时才需要。

## 8. 结论

1. URL Scheme **无法同步**，异步触发延迟不可消除。
2. 竞态根因是"功能 Framework 自行渲染"，不是 URL Scheme。
3. 用**主 App 拉取模式**：URL Scheme 只传意图 + 入口类名；主 App 在 `willConnectTo` 场景就绪后，用 `NSClassFromString` + 协议同步拉取功能 Framework 的 root VC 挂到正确 window。
4. 全程零跨 Framework 内存共享，契合"独立开发 / NSClassFromString / 无统一句柄 / 禁 Redux 跨 Framework"的架构约束。
