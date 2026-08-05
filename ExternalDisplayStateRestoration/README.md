# ExternalDisplayStateRestoration

iPhone 上「单屏主场景 + 外接显示场景」与「场景状态恢复」的可运行 Demo（UIKit）。

## 背景：iPhone 到底能不能「切换 Scene」
iPhone 不支持用户在多个 app 窗口间手动切换（无多窗口切换器）。但 app 进程里可以有多个
UISceneSession：主场景（手机屏）+ 外接显示 session（UIWindowSceneSessionRoleExternalDisplay）
+ CarPlay session，后两者跑在别的显示设备上，不在手机屏上同时显示。

iPhone 上的「场景切换」本质是**同一个 scene session 的 disconnect → reconnect 循环**：
- 切后台：`sceneWillResignActive` → `sceneDidEnterBackground`
- 系统回收：`sceneDidDisconnect`（session 保留，状态存于 `stateRestorationActivity`）
- 回前台：`willConnectTo`（复用同一 session）→ `sceneWillEnterForeground` → `sceneDidBecomeActive`
- 上滑划掉：`application(_:didDiscardSceneSessions:)`（session 销毁，不再恢复）

## 本 Demo 演示
1. 主场景：手机屏显示计数器 / 草稿文字 / 分段选择。
2. 外接显示场景：连接 AirPlay 或线材后，外接屏独立显示一个页面（跑在别的屏上）。
3. 状态恢复：杀掉 App 再打开，计数器 / 文字 / 选择被还原。

## 外接屏如何触发
AppDelegate 监听 `UIScreen.didConnectNotification`，调用
`UIApplication.shared.requestSceneSessionActivation(nil, userActivity:options:errorHandler:)`
系统据 Info.plist 的 `UIWindowSceneSessionRoleExternalDisplay` 配置创建场景。

## SwiftUI 等效
SwiftUI 用 `@SceneStorage` / `NavigationStack(path:)` 自动借助底层 scene session 复用恢复状态；
外部显示仍需在 Info.plist 声明 ExternalDisplay 配置并由 `UIWindowSceneDelegate` 接管。

## 生命周期回调触发顺序
切后台：sceneWillResignActive → sceneDidEnterBackground
系统回收：sceneDidDisconnect（session 保留，状态存于 stateRestorationActivity）
回前台：willConnectTo（带原 session）→ sceneWillEnterForeground → sceneDidBecomeActive
划掉：application(_:didDiscardSceneSessions:)

## 运行
Xcode 新建 iOS App（Interface: Storyboard，Life Cycle: UIKit App Delegate），用本目录文件替换，
确保 Info.plist 含 `UIApplicationSceneManifest`。真机 + 外接显示器验证投屏与状态恢复。

## 文件清单
- AppDelegate.swift
- SceneDelegate.swift（主场景 + 状态恢复）
- ExternalSceneDelegate.swift（外接屏场景）
- MainViewController.swift
- ExternalViewController.swift
- Info.plist（关键片段，合并进项目 Info.plist）
