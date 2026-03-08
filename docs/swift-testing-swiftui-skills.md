# Swift Testing 与 SwiftUI Expert Skill 使用指南

> 基于 Antoine van der Lee 开发的 Agent Skills 总结

---

## 概述

这两个是针对 AI 编码工具的专家技能，遵循 [Agent Skills open format](https://agentskills.io/home)，可集成到 Claude Code、Cursor、Codex 等 AI 助手。

| Skill | 用途 |
|-------|------|
| **Swift Testing Expert** | Swift Testing 测试框架、XCTest 迁移、参数化测试、异步测试、并行执行 |
| **SwiftUI Expert** | SwiftUI 状态管理、视图组合、性能优化、iOS 26+ Liquid Glass |

---

## 安装方式

### 方式 A：skills.sh（推荐）

```bash
# Swift Testing
px skills add https://github.com/avdlee/swift-testing-agent-skill --skill swift-testing-expert

# SwiftUI
px skills add https://github.com/avdlee/swiftui-agent-skill --skill swiftui-expert-skill
```

### 方式 B：Claude Code 插件

```bash
# 添加 marketplace
/plugin marketplace add AvdLee/Swift-Testing-Agent-Skill
/plugin marketplace add AvdLee/SwiftUI-Agent-Skill

# 安装 Skill
/plugin install swift-testing-expert@swift-testing-agent-skill
/plugin install swiftui-expert@swiftui-expert-skill
```

### 方式 C：手动安装

1. Clone 仓库
2. 按工具文档将 skill 文件夹链接到对应目录
3. 使用 AI 工具时指定使用该 skill

---

## 使用方法

在 AI 编码工具中调用：

```
Use the swift testing skill and review this test target for migration opportunities and flaky parallel behavior.
```

```
Use the swiftui expert skill and review the current SwiftUI code for state-management and performance improvements.
```

---

## Swift Testing Skill 能力

### 🏗️ 测试架构指导
- 选择使用 suites、traits、tags、display names 的时机
- 将重复测试转为参数化测试
- 并行安全模式与 `.serialized` 使用
- 标签驱动的测试计划过滤

### ✍️ 更好的测试
- `#expect` + 丰富诊断信息
- `#require` 用于前置条件和安全解包
- 清晰的错误期望建模

### 🔄 XCTest 迁移
- 共存迁移策略
- XCTAssert* → Swift Testing 宏映射
- 保留 XCTest 场景（XCUIApplication、XCTMetric、Objective-C）

### ⚡ 可靠性与性能
- 移除并行执行下的隐藏依赖
- 服务端测试隔离
- 回调 API 桥接到 async/await

---

## SwiftUI Skill 能力

### 🎯 状态管理
- 选择正确的工具：@State、@Binding、@Observable、@Bindable

### 🖼️ 视图组合
- 保持视图身份稳定
- 改善视图可读性与 diff 效率
- 避免不必要的重渲染

### 📱 iOS 26+ Liquid Glass
- 安全使用玻璃效果
- 可用性回退方案

### 🚀 性能优化
- 减少热路径冗余状态更新
- List 性能优化（稳定身份）
- 图片下采样

---

## 目录结构

### Swift Testing
```
swift-testing-expert/
├── SKILL.md
└── references/
    ├── _index.md
    ├── async-testing-and-waiting.md
    ├── expectations.md
    ├── fundamentals.md
    ├── migration-from-xctest.md
    ├── parallelization-and-isolation.md
    ├── parameterized-testing.md
    ├── performance-and-best-practices.md
    ├── traits-and-tags.md
    └── xcode-workflows.md
```

### SwiftUI
```
swiftui-expert-skill/
├── SKILL.md
└── references/
    ├── accessibility-patterns.md
    ├── animation-advanced.md
    ├── animation-basics.md
    ├── animation-transitions.md
    ├── image-optimization.md
    ├── latest-apis.md
    ├── layout-best-practices.md
    ├── liquid-glass.md
    ├── list-patterns.md
    ├── macos-scenes.md
    ├── macos-views.md
    ├── macos-window-styling.md
    ├── performance-patterns.md
    ├── scroll-patterns.md
    ├── sheet-navigation-patterns.md
    ├── state-management.md
    └── view-structure.md
```

---

## 相关资源

- [Swift Testing Skill](https://github.com/AvdLee/Swift-Testing-Agent-Skill)
- [SwiftUI Skill](https://github.com/AvdLee/SwiftUI-Agent-Skill)
- [SwiftLee Swift Testing 文章](https://www.avanderlee.com/category/swift-testing/)
- [SwiftLee SwiftUI 文章](https://www.avanderlee.com/category/swiftui/)
- [Agent Skills 官方格式](https://agentskills.io/home)

---

## 其他相关 Skills

- [Swift Concurrency Expert](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill)
- [Core Data Expert](https://github.com/AvdLee/Core-Data-Agent-Skill)

---

*由 Antoine van der Lee 创建，基于 SwiftLee 文章和 WWDC 2024 内容*
