# SwiftUI & UIKit Jam

## User: swift ui 和 uikit 混合使用时，造成界面卡顿，冻结的原因

1:界面冻结，不能操作，杀 app 重启仍然一样。
2:两者都有，会在同一个 navigating 过程中互相穿插。
3:复杂布局，一个 SwiftUI 下，又组合渲染其他 view 
4:主线程有 ui 渲染，和 TCA 的操作
5:有，但不确定是否冲突
Kimi: SwiftUI 与 UIKit 混合使用时出现卡顿和冻结是常见但棘手的问题。以下是针对你提到的场景的详细分析和解决方案：

---

## 1. 界面冻结且重启无效

**根本原因：** 通常是**状态管理循环**或**无限重绘**导致。

```swift
// ❌ 错误示例：状态循环触发
struct BadView: UIViewControllerRepresentable {
    @Binding var count: Int
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // 危险：这里修改状态会触发重新渲染
        DispatchQueue.main.async {
            count += 1  // 导致无限循环
        }
    }
}
```

**解决方案：**
- 检查 `updateUIViewController` 和 `updateUIView` 中是否有状态修改
- 使用 `Equatable` 或自定义比较逻辑避免不必要的更新
- 添加调试日志追踪渲染次数

---

## 2. 导航过程中穿插使用

**根本原因：** SwiftUI 和 UIKit 的**导航栈生命周期不同步**，过渡动画冲突。

```swift
// ❌ 问题：在 SwiftUI 导航中直接 push UIKit
NavigationLink(destination: UIKitWrapperView()) {
    Text("Go")
}
// UIKitWrapperView 内部又做 navigationController?.pushViewController(...)
```

**解决方案：**
```swift
// ✅ 正确做法：统一导航控制权
struct UIKitNavigationBridge: UIViewControllerRepresentable {
    let destination: UIViewController
    
    func makeUIViewController(context: Context) -> UINavigationController {
        let nav = UINavigationController(rootViewController: UIViewController())
        // 延迟 push，确保当前导航完成
        DispatchQueue.main.async {
            nav.pushViewController(destination, animated: true)
        }
        return nav
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
}
```

**关键原则：** 一个导航操作周期内，只使用一种导航方式。

---

## 3. 复杂嵌套布局性能问题

**根本原因：** SwiftUI 的**布局引擎递归计算** + UIKit 的**自动布局系统**冲突。

```swift
// ❌ 性能杀手
struct ComplexView: View {
    var body: some View {
        VStack {
            ForEach(0..<100) { i in
                UIKitCellWrapper(data: items[i])  // 每个都创建 UIView
            }
        }
    }
}
```

**优化策略：**

| 问题 | 解决方案 |
|------|----------|
| 大量 cell 嵌套 | 使用 `UICollectionView` 完全替代，而非逐个包装 |
| 多层 VStack/HStack | 超过 10 层考虑用 `UIStackView` |
| 动态高度计算 | 使用 `UIViewRepresentable` 的 `sizeThatFits` 预计算 |

```swift
// ✅ 推荐：批量复用而非逐个包装
struct OptimizedList: UIViewRepresentable {
    func makeUIView(context: Context) -> UICollectionView {
        // 使用原生 UICollectionView 的复用机制
        let layout = UICollectionViewFlowLayout()
        return UICollectionView(frame: .zero, collectionViewLayout: layout)
    }
    // ...
}
```

---

## 4. 主线程 UI 渲染 + TCA 操作

**根本原因：** TCA (The Composable Architecture) 的**同步 reducer 执行阻塞主线程**。

```swift
// ❌ 问题：在 reducer 中做耗时操作
Reducer { state, action in
  switch action {
  case .loadData:
    // 同步执行，阻塞主线程 200ms+
    let result = heavyComputation()  
    state.items = result
    return .none
  }
}
```

**解决方案：**

```swift
// ✅ 使用 Effect 异步执行
case .loadData:
  return .run { send in
    // 在后台线程执行
    let result = await heavyComputation()
    await send(.dataLoaded(result))
  }

// ✅ SwiftUI 端使用 receive(on:) 确保 UI 更新在主线程
store.publisher
  .receive(on: DispatchQueue.main)
  .sink { [weak self] _ in
    self?.updateUI()
  }
```

**TCA 最佳实践：**
- Reducer 必须是纯函数，无副作用
- 耗时操作全部包装在 `Effect` 中
- 使用 `.debounce` 和 `.throttle` 控制高频 action

---

## 5. 潜在冲突检测方法

如果你不确定冲突来源，按以下步骤诊断：

```swift
// 1. 启用 SwiftUI 性能调试
// Product -> Scheme -> Edit Scheme -> Run -> Diagnostics
// 勾选 "Color Blended Layers" 和 "Color Offscreen-Rendered"

// 2. 添加运行时检测
extension View {
    func measureRender() -> some View {
        Self._printChanges()  // iOS 15+ 查看哪些状态触发了重绘
        return self
    }
}

// 3. 主线程卡顿检测
import os.log
DispatchQueue.main.async {
    let semaphore = DispatchSemaphore(value: 0)
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
        if semaphore.wait(timeout: .now()) == .timedOut {
            os_log("⚠️ 主线程可能被阻塞")
        }
    }
}
```

---

## 混合使用的黄金法则

| 场景 | 推荐方案 |
|------|----------|
| 简单嵌入 | 使用 `UIViewRepresentable` / `UIViewControllerRepresentable` |
| 复杂列表 | 使用 `UICollectionView` 完全托管，SwiftUI 仅作容器 |
| 导航切换 | 一个页面内只使用一种导航体系 |
| 状态共享 | 使用 `ObservableObject` 作为桥梁，避免双向绑定 |
| 动画过渡 | SwiftUI 动画和 UIKit 动画不要同时触发 |

如果你有具体的代码片段，可以提供给我，我可以帮你做更针对性的分析。
User: 没有代码片段，压根没找到根因。只是有客户上报， App启动完，登录账户后，会卡住，界面不会渲染。
Kimi: 这是一个典型的**启动后初始化阻塞主线程**问题。登录后卡住不渲染，说明登录成功后的某个同步操作阻塞了主线程，或者陷入了死锁/死循环。

以下是系统性的排查思路和可能原因：

---

## 最可能的原因（按概率排序）

### 1. 登录后的同步数据加载阻塞主线程

```swift
// 常见错误模式
func loginSuccess() {
    // ❌ 在主线程同步加载大量数据
    let allData = CoreDataStack.fetchAllRecords() // 10万+ 条数据
    self.items = allData  // 触发 SwiftUI 全量重绘
}
```

**验证方法：** 检查 Instruments - Time Profiler，看主线程是否在 `viewDidLoad` / `onAppear` / `body` 中有长时间占用。

---

### 2. TCA Store 初始化死锁

如果使用了 TCA，登录后创建新 Store 时可能死锁：

```swift
// ❌ 危险：在 init 中发送 action 可能触发循环
let store = Store(
    initialState: LoginState(),
    reducer: loginReducer,
    environment: env
)
// 这里发送 action 如果又触发状态更新...
store.send(.initialize)
```

**验证方法：** 断点检查 `Store` 初始化后是否卡住，检查是否有 `@MainActor` 冲突。

---

### 3. SwiftUI + UIKit 混合时的布局死循环

登录后跳转到主页面，如果主页是混合布局：

```swift
// 可能导致无限布局计算
struct MainView: View {
    var body: some View {
        VStack {
            UIKitMapView()  // 内部有复杂布局
            ScrollView {
                LazyVStack {
                    // 动态高度 + UIKit 嵌入
                }
            }
        }
    }
}
```

**特征：** CPU 占用高但界面不更新，可能是布局引擎在反复计算。

---

### 4. 登录 Token 刷新后的线程问题

```swift
// ❌ 异步回调回主线程时可能有问题
AuthService.login { result in
    // 这里可能在错误的线程
    DispatchQueue.main.async {
        self.isLoggedIn = true  // 触发导航
        self.loadUserData()     // 同步阻塞
    }
}
```

---

## 排查步骤（无需代码，用工具定位）

### Step 1: 确认卡住类型

| 现象 | 可能原因 |
|------|----------|
| 完全冻结，不响应任何操作 | 主线程死锁/死循环 |
| 能滑动但内容不加载 | 异步数据未回调 |
| 白屏/黑屏 | 根视图初始化失败 |
| 能看到部分 UI 但无法交互 | 有透明遮罩层覆盖 |

### Step 2: 使用 Instruments 诊断

```
1. 连接设备，打开 Instruments
2. 选择 Time Profiler
3. 录制从启动到卡住的过程
4. 查看主线程 (Thread 1) 的调用栈
5. 关注是否有：
   - 长时间占用 (>100ms) 的函数
   - 循环调用（调用栈很深且重复）
   - 锁等待（pthread_mutex_lock 等）
```

### Step 3: 检查日志

```swift
// 在 AppDelegate / SceneDelegate 添加
func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    print("✅ Scene willConnect")
}

// 在登录成功处添加
print("✅ Login success - main thread: \(Thread.isMainThread)")
print("✅ Before navigation")
// ...
print("✅ After navigation")
```

看最后输出的日志在哪里中断。

---

## 快速验证清单

请按顺序确认：

1. **卡住时 CPU 占用如何？**
   - 高 CPU → 可能是死循环/大量计算
   - 低 CPU → 可能是死锁/等待

2. **卡住时内存占用？**
   - 内存暴涨 → 可能是数据加载过多
   - 内存正常 → 可能是线程阻塞

3. **是否必现？**
   - 必现 → 代码逻辑问题
   - 偶现 → 可能是竞态条件

4. **特定账号还是所有账号？**
   - 特定账号 → 可能是该账号数据量大
   - 所有账号 → 通用逻辑问题

5. **iOS 版本相关？**
   - 特定版本 → 可能是系统 API 变化

---

## 最可能的根因（基于描述推测）

根据"登录后卡住"这个特征，最可能的是：

> **登录成功后，在主线程同步初始化大量数据/视图，或 TCA Store 的初始 state 计算触发了昂贵的操作。**

建议优先检查：
1. 登录成功后的第一个页面初始化逻辑
2. 是否有在 `init` 或 `onAppear` 中同步加载数据
3. TCA 的 `Store` 创建时是否有复杂的初始 state 计算

如果能提供 Instruments 的 Time Profiler 截图或主线程调用栈，可以更精准定位。
