# ExternalDisplayStateRestorationSUI

iPhone 上「单屏主场景 + 外接显示场景」与「场景状态恢复」的可运行 Demo（SwiftUI 版）。

## 与 UIKit 版的差异
| 维度 | UIKit 版 | SwiftUI 版 |
|------|----------|------------|
| 状态恢复 | 手动 `stateRestorationActivity` + `willConnectTo` | `@SceneStorage` 自动复用 scene session |
| 主场景 | `SceneDelegate` + `UIWindow` | `WindowGroup` 自动管理 |
| 外接屏 | `ExternalSceneDelegate` 托管 `UIViewController` | `SUIExternalSceneDelegate` 托管 `UIHostingController` |
| 触发外接屏 | `requestSceneSessionActivation` | 同左（需 UIKit 桥接调用） |

## 状态恢复说明
SwiftUI 用 `@SceneStorage` 自动借助底层 scene session 复用机制恢复状态：杀掉 App 再打开，
计数器 / 文字 / 选择仍在。这等价于 UIKit 版手动实现的 `stateRestorationActivity`。

## 外接屏触发
主场景由 SwiftUI 自动管理（`WindowGroup`）。外接屏仍需在 Info.plist 声明
`UIWindowSceneSessionRoleExternalDisplay` 配置，并由 `SUIExternalSceneDelegate`（UIKit 桥接）
托管 `UIHostingController` 显示 SwiftUI 的 `ExternalView`。

## 运行
Xcode 新建 iOS App（Interface: SwiftUI，Life Cycle: SwiftUI App），用本目录文件替换，
确保 Info.plist 含 `UIApplicationSceneManifest` 及 external display 配置。
真机 + 外接显示器验证投屏与状态恢复。

## 文件清单
- ExternalDisplayStateRestorationSUIApp.swift（@main App）
- ContentView.swift（主场景，@SceneStorage 状态恢复）
- ExternalView.swift（外接屏内容）
- SUIExternalSceneDelegate.swift（UIKit 桥接托管外接屏）
- Info.plist（关键片段，合并进项目 Info.plist）
