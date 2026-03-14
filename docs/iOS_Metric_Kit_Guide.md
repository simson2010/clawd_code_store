# iOS Metric Kit 完全指南

> 本文档详细介绍 iOS Metric Kit 的使用范围、能力，重点讲解冷启动数据收集机制与实践优化。

**作者**: King Lobster 🦞  
**日期**: 2026-03-12  
**更新**: 2026-03-14

---

## 目录

1. [Metric Kit 概述](#1-metric-kit-概述)
2. [核心能力](#2-核心能力)
3. [冷启动数据收集](#3-冷启动数据收集)
4. [实践代码](#4-实践代码)
5. [启动优化指南](#5-启动优化指南)
   - [5.0 启动阶段细分耗时深度解读](#50-启动阶段细分耗时深度解读)
   - [5.1 常见优化策略](#51-常见优化策略)
6. [数据查看与分析](#6-数据查看与分析)

---

## 1. Metric Kit 概述

### 1.1 什么是 Metric Kit？

Metric Kit 是 Apple 提供的性能分析框架（iOS 13+），用于收集应用的崩溃、卡顿、内存、电池等性能数据。与传统第三方分析工具（如 Firebase Crashlytics）不同，Metric Kit 是 Apple 原生方案，**无需额外 SDK 集成**，数据直接通过 Xcode Organizer 和 App Store Connect 展示。

### 1.2 发展历程

| 版本 | 发布时间 | 新增功能 |
|------|----------|----------|
| iOS 13 | 2019.09 | 初始版本，支持崩溃、卡顿、内存 |
| iOS 14 | 2020.09 | 新增启动时间指标，区分冷/热启动 |
| iOS 15 | 2021.09 | 优化数据聚合，支持 Pre-lingering |
| iOS 16 | 2022.09 | 新增 Launch Timeline，阶段细分 |
| iOS 17 | 2023.09 | 增强电池分析，新增 disk I/O 指标 |

### 1.3 适用平台

- **iOS**: 13.0+
- **iPadOS**: 13.0+
- **macOS**: 11.0+ (Mac Catalyst)
- **tvOS**: 不支持
- **watchOS**: 不支持

---

## 2. 核心能力

### 2.1 能力一览表

| 类别 | 指标 | iOS 版本 | 说明 |
|------|------|----------|------|
| **崩溃报告** | Crashes | iOS 13+ | 收集崩溃堆栈、异常类型、信号 |
| **卡顿检测** | Hang | iOS 13+ | 检测主线程阻塞超过阈值 |
| **内存** | Memory | iOS 13+ | 内存峰值、压力事件、VM tracker |
| **电池** | Battery | iOS 13+ | CPU 使用、后台活动、发热 |
| **启动时间** | Launch | iOS 14+ | 冷/热启动耗时 |
| **启动分解** | Timeline | iOS 16+ | 各阶段详细耗时 |
| **磁盘 I/O** | Disk | iOS 17+ | 读写数据量 |

### 2.2 崩溃报告 (Crashes)

```swift
// 获取崩溃数据
let crashMetrics = payload.crashMetrics

// 崩溃类型统计
let crashCount = crashMetrics.crashCount
let crashRate = crashMetrics.crashRate

// 按崩溃类型分组
for histogram in crashMetrics.crashHistograms {
    print("类型: \(histogram.crashType)")
    print("次数: \(histogram.count)")
}
```

**崩溃类型**:
- `signal`: Unix 信号崩溃 (SIGABRT, SIGSEGV 等)
- `exception`: Objective-C 异常
- `lowMemory`: 内存不足崩溃
- `watchdog`: 看门狗超时

### 2.3 卡顿检测 (Hangs)

Metric Kit 会检测主线程阻塞超过 **500ms** 的情况：

```swift
let hangMetrics = payload.hangMetrics

// 卡顿统计
let hangCount = hangMetrics.hangCount
let hangRate = hangMetrics.hangRate

// 卡顿时长分布
let histogram = hangMetrics.durationsHistogram
```

### 2.4 内存监控 (Memory)

```swift
let memoryMetrics = payload.memoryMetrics

// 内存峰值
let peakMemory = memoryMetrics.peakMemoryUsage

// 内存压力事件
let memoryPressureCount = memoryMetrics.jetsamCount

// 虚拟内存使用
let vmFootprint = memoryMetrics.vmFootprint
```

### 2.5 电池分析 (Battery)

```swift
let batteryMetrics = payload.batteryMetrics

// CPU 使用时间
let cpuTime = batteryMetrics.cpuTime

// 后台活动
let backgroundTime = batteryMetrics.backgroundTime

// 发热事件
let thermalEventCount = batteryMetrics.thermalEventCount
```

---

## 3. 冷启动数据收集

### 3.1 启动类型定义

| 类型 | 英文 | 说明 | 触发条件 |
|------|------|------|----------|
| **冷启动** | Cold Launch | App 进程不存在，需完全重建 | 设备重启后首次启动/进程被杀死 |
| **热启动** | Warm Launch | App 在后台，系统恢复其状态 | App 进入后台后恢复 |
| **恢复** | Resume | 从后台恢复到前台 | 按 Home 键后重新打开 |

### 3.2 启动阶段分解

#### iOS 13-15: 简单阶段划分

```swift
let launchMetrics = payload.applicationLaunchMetrics

// iOS 14+ 可用
let coldLaunch = launchMetrics.coldLaunchTimeInterval      // 冷启动
let warmLaunch = launchMetrics.warmLaunchTimeInterval      // 热启动
let resume = launchMetrics.resumeTimeInterval              // 恢复
```

#### iOS 16+: 详细时间线 (Launch Timeline)

iOS 16 引入了更详细的启动分解：

```swift
if #available(iOS 16.0, *) {
    let timeline = launchMetrics.launchTimeline
    
    // 各阶段耗时
    let dylibTime = timeline.dylibLoadingDuration          // 动态库加载
    let runtimeInit = timeline.runtimeInitializationDuration  // Runtime 初始化
    let UIKitInit = timeline.uiKitInitializationDuration    // UIKit 初始化
    let firstFrame = timeline.firstFrameRenderingDuration   // 首帧渲染
}
```

### 3.3 启动阶段详解

```
┌─────────────────────────────────────────────────────────────────┐
│                        冷启动全流程                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────┐ │
│  │   Pre-Main   │ →  │   UI 创建    │ →  │   首帧渲染      │ │
│  │  (dylib加载)  │    │  (main后)    │    │  (LaunchScreen) │ │
│  └──────────────┘    └──────────────┘    └──────────────────┘ │
│                                                                 │
│  ⏱️ 典型耗时占比:                                               │
│  - Pre-Main: 30-50%                                            │
│  - UI 创建: 20-40%                                              │
│  - 首帧渲染: 20-30%                                             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### 阶段 1: Pre-Main (main() 之前)

- **动态库加载 (dylib loading)**: 解析依赖、加载系统库
- **Runtime 初始化**: Objective-C / Swift 运行时
- **+load / constructor**: 静态初始化代码

#### 阶段 2: UI 创建 (main() 到 首帧)

- **AppDelegate 方法**: `application(_:didFinishLaunchingWithOptions:)`
- **UI 初始化**: Window、RootViewController 创建
- **LaunchScreen**: 启动图展示

#### 3.4 启动指标详解

```swift
struct ApplicationLaunchMetrics {
    /// 冷启动耗时 (iOS 14+)
    let coldLaunchTimeInterval: TimeInterval
    
    /// 热启动耗时 (iOS 14+)
    let warmLaunchTimeInterval: TimeInterval
    
    /// 从后台恢复耗时 (iOS 14+)
    let resumeTimeInterval: TimeInterval
    
    /// 首帧渲染前耗时 (iOS 14+)
    let applicationUILaunchTimeInterval: TimeInterval
    
    /// main() 之前耗时 (iOS 14+)
    let preMainTimeInterval: TimeInterval
    
    /// 启动时间线详情 (iOS 16+)
    let launchTimeline: LaunchTimeline
}
```

### 3.5 数据聚合机制

| 阶段 | 说明 |
|------|------|
| **收集** | 设备本地实时收集指标 |
| **聚合** | 每天 UTC 00:00 重置，开始新一天聚合 |
| **上报** | 每周一 App Store Connect 更新（非实时） |
| **展示** | Xcode Organizer / App Store Connect |

> ⚠️ **注意**: Metric Kit 数据有 **1-7 天延迟**，不适用于实时监控。

---

## 4. 实践代码

### 4.1 基础集成

```swift
import MetricKit
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    override init() {
        super.init()
        
        // 注册 Metric Manager
        let manager = MXMetricManager.shared
        
        // 添加自身为指标接收者
        manager.add(self)
    }
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return true
    }
}

// 实现 MXMetricManagerSubscriber 协议
extension AppDelegate: MXMetricManagerSubscriber {
    
    /// 接收指标回调 - 每天调用一次
    func metricManager(
        _ manager: MXMetricManager,
        didReceive payload: MXMetricPayload
    ) {
        // 处理启动指标
        handleLaunchMetrics(payload.applicationLaunchMetrics)
        
        // 处理崩溃指标
        handleCrashMetrics(payload.crashMetrics)
        
        // 处理内存指标
        handleMemoryMetrics(payload.memoryMetrics)
        
        // 处理卡顿指标
        handleHangMetrics(payload.hangMetrics)
        
        // 处理电池指标
        handleBatteryMetrics(payload.batteryMetrics)
    }
    
    private func handleLaunchMetrics(_ metrics: MXApplicationLaunchMetrics) {
        print("========== 启动指标 ==========")
        print("冷启动: \(metrics.coldLaunchTimeInterval)s")
        print("热启动: \(metrics.warmLaunchTimeInterval)s")
        print("恢复: \(metrics.resumeTimeInterval)s")
        print("UI 启动: \(metrics.applicationUILaunchTimeInterval)s")
        
        if #available(iOS 14.0, *) {
            print("Pre-Main: \(metrics.preMainTimeInterval)s")
        }
        
        if #available(iOS 16.0, *) {
            let timeline = metrics.launchTimeline
            print("--- 启动时间线 (iOS 16+) ---")
            print("动态库加载: \(timeline.dylibLoadingDuration)s")
            print("Runtime 初始化: \(timeline.runtimeInitializationDuration)s")
            print("UIKit 初始化: \(timeline.uiKitInitializationDuration)s")
            print("首帧渲染: \(timeline.firstFrameRenderingDuration)s")
        }
    }
    
    private func handleCrashMetrics(_ metrics: MXCrashMetrics) {
        print("========== 崩溃指标 ==========")
        print("崩溃次数: \(metrics.crashCount)")
        
        for histogram in metrics.crashHistograms {
            print("类型: \(histogram.crashType), 次数: \(histogram.count)")
        }
    }
    
    private func handleMemoryMetrics(_ metrics: MXMemoryMetrics) {
        print("========== 内存指标 ==========")
        print("峰值内存: \(metrics.peakMemoryUsage / 1024 / 1024) MB")
        print("内存压力事件: \(metrics.jetsamCount)")
    }
    
    private func handleHangMetrics(_ metrics: MXHangMetrics) {
        print("========== 卡顿指标 ==========")
        print("卡顿次数: \(metrics.hangCount)")
        print("卡顿率: \(metrics.hangRate * 100)%")
    }
    
    private func handleBatteryMetrics(_ metrics: MXBatteryMetrics) {
        print("========== 电池指标 ==========")
        print("CPU 时间: \(metrics.cpuTime)s")
        print("后台时间: \(metrics.backgroundTime)s")
    }
}
```

### 4.2 自定义指标 (Custom Metrics)

Metric Kit 支持添加自定义性能指标：

```swift
import MetricKit

class CustomMetricManager {
    
    static let shared = CustomMetricManager()
    private let manager = MXMetricManager.shared
    
    private init() {}
    
    /// 记录启动结束点
    func recordInitialLaunchEnd() {
        let metric = MXMetricObject(
            name: "initialLaunchEnd",
            unit: "seconds",
            dimensions: [:]
        )
        
        // 创建包含启动时间的 payload
        let dimensions: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970,
            "bootTime": ProcessInfo.processInfo.systemUptime
        ]
        
        // 注意: 自定义指标需要使用 MXMetricManager 的其他 API
        // 这里仅作示例展示思路
    }
}
```

### 4.3 条件编译与版本适配

```swift
import MetricKit
import UIKit

extension MXApplicationLaunchMetrics {
    
    /// 获取完整的启动诊断信息
    var diagnosticDescription: String {
        var info = """
        启动类型: 冷启动
        总耗时: \(coldLaunchTimeInterval)s
        """
        
        if #available(iOS 14.0, *) {
            info += """
            
            Pre-Main: \(preMainTimeInterval)s
            UI 启动: \(applicationUILaunchTimeInterval)s
            """
        }
        
        if #available(iOS 16.0, *) {
            let timeline = launchTimeline
            info += """
            
            启动时间线详情:
            - 动态库加载: \(timeline.dylibLoadingDuration)s
            - Runtime 初始化: \(timeline.runtimeInitializationDuration)s
            - UIKit 初始化: \(timeline.uiKitInitializationDuration)s
            - 首帧渲染: \(timeline.firstFrameRenderingDuration)s
            """
        }
        
        return info
    }
}
```

### 4.4 启动时间监控工具类

```swift
import Foundation
import MetricKit

/// 启动时间监控工具
final class LaunchTimeMonitor {
    
    /// 单例
    static let shared = LaunchTimeMonitor()
    
    /// 启动各阶段时间戳
    private var timestamps: [String: Date] = [:]
    
    /// 阶段名称
    enum Stage: String, CaseIterable {
        case appStart = "app_start"           // 进程创建
        case mainCalled = "main_called"        // main() 被调用
        case didFinishLaunching = "did_finish_launching"  // didFinishLaunching 完成
        case firstFrame = "first_frame"       // 首帧渲染
        case interactive = "interactive"      // 可交互
    }
    
    private init() {}
    
    /// 记录阶段时间点
    func record(_ stage: Stage) {
        timestamps[stage.rawValue] = Date()
    }
    
    /// 获取阶段耗时
    func duration(from: Stage, to: Stage) -> TimeInterval? {
        guard let fromDate = timestamps[from.rawValue],
              let toDate = timestamps[to.rawValue] else {
            return nil
        }
        return toDate.timeIntervalSince(fromDate)
    }
    
    /// 获取诊断报告
    func diagnosticReport() -> String {
        var report = "========== 启动诊断报告 ==========\n"
        
        for stage in Stage.allCases {
            if let time = timestamps[stage.rawValue] {
                report += "\(stage.rawValue): \(time.timeIntervalSince1970)\n"
            }
        }
        
        // 计算关键耗时
        if let mainToFinish = duration(from: .mainCalled, to: .didFinishLaunching) {
            report += "\nmain → didFinishLaunching: \(mainToFinish)s\n"
        }
        
        if let finishToFrame = duration(from: .didFinishLaunching, to: .firstFrame) {
            report += "didFinishLaunching → 首帧: \(finishToFrame)s\n"
        }
        
        return report
    }
}

// 使用示例
/*
 
 // 在 main.swift 或 AppDelegate 中:
 LaunchTimeMonitor.shared.record(.appStart)
 
 // main() 后:
 LaunchTimeMonitor.shared.record(.mainCalled)
 
 // didFinishLaunching 完成后:
 LaunchTimeMonitor.shared.record(.didFinishLaunching)
 
 // 首帧渲染回调中:
 LaunchTimeMonitor.shared.record(.firstFrame)
 
 // 打印诊断:
 print(LaunchTimeMonitor.shared.diagnosticReport())
 
 */
```

---

## 5. 启动优化指南

### 5.0 启动阶段细分耗时深度解读

#### 5.0.1 冷启动完整时间线

```
┌─────────────────────────────────────────────────────────────────┐
│                        COLD LAUNCH                              │
├──────────────────────┬──────────────────────────────────────────┤
│   PRE-MAIN           │            POST-MAIN                    │
│   (内核态)            │            (用户态)                      │
├──────────────────────┼──────────────────────────────────────────┤
│ 1. 内核引导          │ 5. UIKit 初始化                          │
│ 2. 动态链接器加载    │ 6. AppDelegate lifecycle                  │
│ 3. +load / C++ init  │ 7. 启动屏消失                             │
│ 4. main() 函数       │ 8. 首帧渲染 / 首屏内容展示                │
└──────────────────────┴──────────────────────────────────────────┘
```

#### 5.0.2 MetricKit 中的细分指标 (iOS 16+)

| 阶段 | 关键指标 | 含义 |
|------|---------|------|
| **Time to First Draw** | `timestampFirstDraw` | 从 launch 到首帧渲染 |
| **Application Initializers** | `initializerDuration` | `+load` / C++ 静态初始化耗时 |
| **UIKit Setup** | `UIKitInitializationDuration` | UIKit 框架初始化 |
| **Framework Load** | 隐含在初始化中 | 动态库加载时间 |

#### iOS 17+ 增强的指标

```swift
// MXAppLaunchMetric 新增字段 (iOS 17+)
let launchMetric = payload.applicationLaunchMetrics

// 1. 完整启动耗时
let totalDuration = launchMetric.duration

// 2. 启动类型
let launchType = launchMetric.launchType // .cold, .warm, .resume

// 3. 初始化器耗时 (C++ static init, +load)
let initDuration = launchMetric.initializerDuration

// 4. 启动结束原因
let termination = launchMetric.terminationReason
```

#### 5.0.3 各阶段耗时解读

##### 1. PRE-MAIN 阶段（内核引导 + 动态链接）

```
典型耗时: 100-300ms (设备越新越快)
```

| 指标 | 正常范围 | 异常信号 |
|------|---------|---------|
| 动态链接器加载 | < 150ms | > 300ms 说明依赖过多 |
| C++ 静态初始化 | < 50ms | > 100ms 有过多 static 变量 |

**优化方向**：
- 减少动态库依赖（合并 Framework）
- 减少 `+load` 方法（改用 `+initialize` 或懒加载）
- 减少 static 变量数量

##### 2. POST-MAIN 阶段 - application(_:didFinishLaunchingWithOptions:)

```
典型耗时: 200-800ms
```

这个阶段包含：
- 第三方 SDK 初始化
- 数据库打开
- 网络模块配置
- 权限请求
- 埋点初始化

**优化方向**：
- 异步初始化（非关键 SDK 延迟加载）
- 按需加载模块
- 避免在 `didFinishLaunching` 中做同步网络请求

##### 3. 首帧渲染 (First Frame)

```
典型耗时: 100-500ms
```

这是用户感知最强的阶段：
- 启动屏消失时间
- 首个 `UIViewController` 的 `viewDidAppear` 完成

**优化方向**：
- 启动屏与首屏无缝衔接
- 减少首屏 ViewController 的 `viewDidLoad` 工作
- 预渲染首屏内容

#### 5.0.4 实际数据解读示例

假设 MetricKit 报告如下：

```
totalDuration:        1,450ms
initializerDuration:  120ms    (8%)
didFinishLaunching:   650ms    (45%)
First Draw:           680ms    (47%)
```

**解读**：

| 阶段 | 占比 | 评估 |
|------|------|------|
| 初始化器 | 8% | ✅ 正常范围 |
| didFinishLaunching | 45% | ⚠️ 偏重，需优化 |
| 首帧渲染 | 47% | ⚠️ 可能有过多 UI 构建 |

**优化建议**：
1. `didFinishLaunching` 中的任务异步化
2. 检查首屏是否有过多 View 懒加载

#### 5.0.5 性能基准参考

| 设备类型 | 优秀 | 良好 | 需优化 | 严重 |
|---------|------|------|-------|------|
| iPhone 15 Pro | < 800ms | 800-1500ms | 1500-2500ms | > 2500ms |
| iPhone 13 | < 1000ms | 1000-1800ms | 1800-3000ms | > 3000ms |
| iPhone 11 | < 1200ms | 1200-2000ms | 2000-3500ms | > 3500ms |

#### 5.0.6 细分阶段数据获取方法

除了 MetricKit，还可以用 **Instruments** 辅助分析：

```bash
# Time Profiler
# 打开 Xcode -> Product -> Profile -> Time Profiler

# System Trace (iOS 15+)
# 更细粒度的系统级分析
```

关键符号点：
- `main()` 入口
- `UIApplicationMain` 
- `-[UIApplication run]`
- `-[UIWindow makeKeyAndVisible]`

---

### 5.1 常见优化策略

#### 5.1.1 减少动态库依赖

```objc
// ❌ 不推荐: 大量系统库导入
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
// ... 更多

// ✅ 推荐: 按需导入
#import <Foundation/Foundation.h>
// 仅在需要时导入 UIKit
```

**优化建议**:
- 优先使用系统 unified headers
- 避免非必要的第三方库
- 使用 **dlopen** 延迟加载可选功能

#### 5.1.2 优化 +load 方法

```objc
// ❌ 不推荐: 在 +load 中做耗时操作
+ (void)load {
    [self fetchConfigFromNetwork];  // 网络请求!
    [self initializeDatabase];       // 数据库初始化
    [self setupAnalytics];            // 分析SDK
}

// ✅ 推荐: 延迟到首次使用时
+ (void)load {
    // 仅记录需要初始化的标记
    _needsInitialization = YES;
}

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 延迟初始化
    });
}
```

#### 5.1.3 优化 didFinishLaunching

```swift
// ❌ 不推荐: 在 didFinishLaunching 中同步执行
func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
    // 同步网络请求 - 阻塞启动!
    let config = fetchConfigSync()
    
    // 同步数据库查询
    let data = loadDataSync()
    
    // 同步复杂计算
    processData()
    
    return true
}

// ✅ 推荐: 异步延迟处理
func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
    // 立即返回，启动优先
    
    // 延迟到下一个 runloop 或后台任务
    DispatchQueue.main.async {
        self.initializeServices()
    }
    
    return true
}
```

#### 5.1.4 使用 Swift 延迟加载

```swift
class MyAppDelegate: UIResponder, UIApplicationDelegate {
    
    // ❌ 不推荐: 提前初始化
    let database = DatabaseManager()
    let configLoader = ConfigLoader()
    
    // ✅ 推荐: lazy 延迟加载
    lazy var database: DatabaseManager = {
        return DatabaseManager()
    }()
    
    lazy var configLoader: ConfigLoader = {
        return ConfigLoader()
    }()
}
```

### 5.2 LaunchScreen 优化

```xml
<!-- ✅ 推荐: 简单的 LaunchScreen -->
<plist version="1.0">
<dict>
    <key>UILaunchStoryboardName</key>
    <string>LaunchScreen</string>
    <key>UILaunchScreen</key>
    <dict>
        <key>UIColorName</key>
        <string>LaunchBackground</string>
        <key>UIImageName</key>
        <string></string>
    </dict>
</dict>
</plist>
```

**建议**:
- 使用纯色背景而非复杂图片
- 避免在 LaunchScreen 中使用过多元素
- 图片优先使用 PDF vector 图

### 5.3 预启动 (Pre-lingering) - iOS 15+

iOS 15 引入了 **Pre-lingering**，允许系统提前预热 app：

```swift
// 在 Info.plist 中启用
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.app.prewarm</string>
</array>

// 注册预启动任务
func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
    
    // iOS 15+ 预启动回调
    if #available(iOS 15.0, *) {
        // 处理 pre-lingering 启动
        // 这次启动耗时更短，因为部分资源已被预加载
    }
    
    return true
}
```

### 5.4 优化检查清单

| 检查项 | 优先级 | 说明 |
|--------|--------|------|
| 减少动态库数量 | ⭐⭐⭐ | 目标是 < 6 个非系统 dylib |
| 移除 +load 中的耗时操作 | ⭐⭐⭐ | 移到 initialize 或延迟加载 |
| didFinishLaunching 异步化 | ⭐⭐⭐ | 不要阻塞主线程 |
| 使用 lazy 加载 | ⭐⭐ | 按需初始化 |
| 优化 LaunchScreen | ⭐⭐ | 简单化，避免大图 |
| 启用 Pre-lingering | ⭐ | iOS 15+ 充分利用 |
| 减少 TBD 依赖 | ⭐ | Text-based Dylib 加快加载 |

---

## 6. 数据查看与分析

### 6.1 Xcode Organizer

```
Xcode → Window → Organizer → Metrics
```

查看内容:
- 崩溃趋势
- 卡顿趋势
- 启动时间分布
- 内存使用
- 电池消耗

### 6.2 App Store Connect

```
App Store Connect → Analytics → Metrics
```

指标对比:
- 按 iOS 版本查看
- 按设备型号查看
- 按地区查看

### 6.3 崩溃符号化

Metric Kit 自动符号化，但需确保:

1. **Xcode 自动符号化**: 保持 `Debug Information Format` 为 `DWARF with dSYM`
2. **上传 dSYM**: App Store Connect 会自动处理

---

## 附录

### A. 参考资源

- [Apple Metric Kit 官方文档](https://developer.apple.com/documentation/metrickit)
- [WWDC 2019 - Introducing MetricKit](https://developer.apple.com/videos/play/wwdc2019/420/)
- [WWDC 2020 - MetricKit 深度解读](https://developer.apple.com/videos/play/wwdc2020/10078/)
- [WWDC 2022 - 启动时间优化](https://developer.apple.com/videos/play/wwdc2022/10168/)

### B. 相关框架

| 框架 | 说明 |
|------|------|
| **Instruments** | 实时性能分析工具 |
| **XCTest** | 性能基准测试 |
| **os_signpost** | 自定义性能标记 |
| **BackgroundTasks** | 后台任务调度 |

### C. 常见问题

**Q: Metric Kit 数据有延迟吗?**
> A: 是的，通常 1-7 天延迟，不适合实时监控。

**Q: 可以在本地测试 Metric Kit 吗?**
> A: 可以，但 Xcode Organizer 的数据需要上传到 App Store Connect 后才能查看完整报告。

**Q: Metric Kit 会收集用户隐私数据吗?**
> A: 不会。Metric Kit 仅收集聚合的性能统计数据，不包含用户个人信息。

**Q: 如何区分调试和发布环境的指标?**
> A: Metric Kit 会在 Debug 模式下收集数据，但 Xcode Organizer 主要显示 Release 环境的统计。

---

## 更新日志

| 日期 | 更新内容 |
|------|----------|
| 2026-03-12 | 初始版本，涵盖 MetricKit 基础使用 |
| 2026-03-14 | 新增 5.0 启动阶段细分耗时深度解读 |

---

*本文档由 King Lobster 🦞 整理*
