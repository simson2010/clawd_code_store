# Flutter App → SwiftUI 原生重写：方案集 + 工具

把一套 Flutter App（有源码、有 Figma、有自建 GenUI）重写为 Swift / SwiftUI 原生 App 的完整方案演进记录，以及配套的可执行脚本。

## 版本演进与阅读顺序

方案经过四轮补充才定型。**后面的版本会推翻前面的结论**，下表标明了哪些已被取代：

| 编号 | 文档 | 状态 | 说明 |
|---|---|---|---|
| 01 | 调研报告-Flutter转SwiftUI迁移路径 | 历史参考 | 业界 Skill 盘点、Dart→Swift 映射表、四阶段工作流 |
| 02 | 组件映射落地指南 | 历史参考 | 三层拆解（视觉/结构/行为）、Design Token 桥、App 级适配层 |
| 03 | 方案评审与落地细化 | **部分有效** | 两层拆分、Screen Spec、SDK 分层仍有效；灰度与数据迁移部分已被 05 推翻 |
| 04 | 方案 V2-六条补充修订 | **已被 05 取代** | "Flutter 未上线"的前提后来被推翻，勿直接引用 |
| 05 | **方案 V3-终版落地计划** | ⭐ **当前有效** | 产线与文件所有权、九项缺口、数据迁移、P0–P7 路线图 |
| 06 | **方案 V3.1-组件库就绪后的调整** | ⭐ **最新补充** | 组件库完备后的工期压缩与六项新增依赖风险 |
| 07 | 给管理层-UI 应从 Figma 生成 | 对外汇报用 | 六论据 + 成本模型 + 常见质疑应答 |

**按角色选读：**

| 你是 | 读什么 |
|---|---|
| 管理者 / 需要立项 | 07 → 06 §0 → 05 §11（一句话总结） |
| 架构负责人 | 05 全文 → 06 全文 |
| 一线开发（写 Feature） | 05 §2（文件所有权 + 三层 State）→ `templates/screen_spec.md` |
| 项目经理（排期） | 05 §8 路线图 → 06 §6 修订后 P0/P1 → `templates/p0_kickoff_checklist.md` |

## 目录结构

```
flutter-to-swiftui/
├── 01 ~ 07              方案文档（按演进顺序编号）
├── templates/
│   ├── screen_spec.md           每个屏幕的行为契约模板（Analyzer Agent 的唯一输出格式）
│   └── p0_kickoff_checklist.md  P0 阶段可执行检查清单（含出口标准）
├── tools/
│   └── scan_flutter_widgets.py  Flutter 组件清单扫描器
└── samples/
    ├── sample_flutter_app/      用于验证脚本的最小 Flutter 样例工程
    └── expected_output/         该样例的预期扫描输出（可作回归基准）
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
| 最大工程风险 | GenUI 重新生成时吃掉手写逻辑 → 必须做文件所有权隔离 + CI 守护 |
| State 冲突解法 | 三层分离：`view`（GenUI 生成）+ `domain`（手写）+ 外层 `State` 组合 |
| P1 出口标准 | 改一次设计稿 → 重新生成 → 业务逻辑不丢 |
| 数据迁移 | 不要在 Native 侧猜 Flutter 私有存储格式；在 Flutter 倒数第二个版本**预埋 JSON 导出** |
| 最低 iOS 目标 | 16 以上 → `@Observable` / `SwiftData` / `ContentUnavailableView` 全部不可用 |
| 最高性价比动作 | 抽取线上 App 的 TCA Feature 做 Agent 的 few-shot 语料库（约 1 人 3 天） |
