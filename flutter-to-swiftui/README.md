# Flutter App → SwiftUI 原生重写：方案 + 工具

把一套 Flutter App（有源码、有 Figma、有自建 GenUI）重写为 Swift / SwiftUI 原生 App 的落地方案与配套工具。

## 读哪一份

| 文档 | 说明 |
|---|---|
| **`00-方案V4-暂定最终版.md`** | ⭐ **唯一事实源**。已合并 V1→V3.1 全部迭代，引用一律以此为准 |
| `07-给管理层-UI应从Figma生成而非源码推导.md` | 对外汇报用：六论据 + 成本模型 + 常见质疑应答 |
| `archive/01`–`06` | 历史版本（调研 → V1 → V2 → V3 → V3.1），仅供溯源，**勿引用** |

**按角色选读（都读 00 号）：**

| 你是 | 读什么 |
|---|---|
| 管理者 / 立项 | 07 → 00 §1（一页纸摘要） |
| 架构负责人 | 00 全文，重点 §3（产线架构）§5（子系统）§9（风险） |
| 一线开发 | 00 §3（文件所有权 + 三层 State）→ `templates/screen_spec.md` |
| 项目经理 | 00 §8 路线图 + §10 待决策清单 → `templates/p0_kickoff_checklist.md` |

## 目录结构

```
flutter-to-swiftui/
├── 00-方案V4-暂定最终版.md       ⭐ 唯一事实源
├── 07-给管理层-....md            对外汇报
├── archive/                      历史版本（勿引用）
├── templates/
│   ├── screen_spec.md            每个屏幕的行为契约模板（Analyzer Agent 唯一输出格式）
│   └── p0_kickoff_checklist.md   P0 阶段可执行检查清单（含出口标准）
├── tools/
│   └── scan_flutter_widgets.py   Flutter 组件清单扫描器
└── samples/
    ├── sample_flutter_app/       验证脚本的最小 Flutter 样例工程
    └── expected_output/          预期扫描输出（回归基准）
```

## 工具

### scan_flutter_widgets.py

纯 Python 标准库实现，**不需要 Dart SDK**。扫描 Flutter 工程，产出：

- 自定义组件清单（引用次数、基类、必填/总参数）
- UI 基线判断（Material / Cupertino / 自绘）
- 疑似 Design System 组件识别（引用广 + 命名成体系 + 位于 `widgets/` 目录）
- 行为层与风险打标（埋点、Timer、Controller、BackdropFilter、CustomPainter、Platform Channel …）

```bash
python3 tools/scan_flutter_widgets.py --path <Flutter工程路径> --out ./mapping-out
```

输出三种格式：`widget_inventory.md`（人读）、`.csv`（表格）、`.json`（程序消费）。

**用自带样例验证：**

```bash
python3 tools/scan_flutter_widgets.py \
  --path samples/sample_flutter_app \
  --out /tmp/verify

diff <(cat /tmp/verify/widget_inventory.md) samples/expected_output/widget_inventory.md
```

若无 diff，说明脚本行为正常。修改脚本后应重跑此验证。

## 关键结论速查

| 主题 | 结论 |
|---|---|
| 有没有一键转译器 | 没有，也不可能有。渲染模型根本不同（自绘 vs 原生组件） |
| 产线分工 | **GenUI 出 UI + TCA 骨架（可再生层），Agent 出 Reducer 业务逻辑（持久层）** |
| 最大工程风险 | GenUI 重新生成时吃掉手写逻辑 → 文件所有权隔离 + CI 守护 |
| State 冲突解法 | 三层分离：`view`（GenUI 生成）+ `domain`（手写） |
| P1 出口标准 | 改一次设计稿 → 重新生成 → 业务逻辑不丢 |
| 数据迁移 | 不猜 Flutter 私有存储格式；Flutter 倒数第二版**预埋 JSON 导出** |
| 最低 iOS 目标 | 16 → `@Observable` / `SwiftData` / `ContentUnavailableView` 不可用 |
| 最高性价比动作 | 抽取线上 App 的 TCA Feature 做 Agent few-shot 语料库（约 1 人 3 天） |
