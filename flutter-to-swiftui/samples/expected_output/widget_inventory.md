# Flutter 组件清单报告

- 扫描路径：`samples/sample_flutter_app`
- Dart 文件数：**5**
- 自定义组件数：**7**
- **UI 基线判断**：Material（Material Design 观感，迁移到 SwiftUI 需要重新定性视觉）
  - Material 调用 6 次 / Cupertino 调用 0 次

## 一、疑似设计系统组件（优先处理）

这些组件是公司自有组件库的核心，迁移时应优先确认公司 iOS DS 里有没有对应物。

| 组件 | 引用次数 | 基类 | 必填/总参数 | 危险信号 | 路径 |
|---|---|---|---|---|---|
| `AppCard` | 2 | Stateless | 1/4 | — | `lib/widgets/app_card.dart` |
| `AppButton` | 1 | Stateless | 2/6 | — | `lib/widgets/app_button.dart` |
| `AppBlurPanel` | 0 | Stateless | 1/2 | 实时背景模糊 → Material / UIVisualEffectView | `lib/widgets/app_card.dart` |

## 二、全部自定义组件（按引用次数降序）

| 组件 | 基类 | 引用 | 必填/总参数 | 危险信号 |
|---|---|---|---|---|
| `AppCard` | StatelessWidget | 2 | 1/4 | — |
| `MyApp` | StatelessWidget | 1 | 0/1 | — |
| `HomeScreen` | StatefulWidget | 1 | 0/1 | — |
| `AppButton` | StatelessWidget | 1 | 2/6 | — |
| `TrendChart` | StatelessWidget | 1 | 1/2 | 自绘画布委托 → SwiftUI Canvas / Path 手绘 |
| `_TrendPainter` | CustomPainter ·自绘 | 1 | 0/0 | 自绘/渲染型 → 无 SwiftUI 等价物，必须重写 |
| `AppBlurPanel` | StatelessWidget | 0 | 1/2 | 实时背景模糊 → Material / UIVisualEffectView |

## 三、Flutter SDK 组件用量

| Widget | 出现次数 |
|---|---|
| `Text` | 3 |
| `Scaffold` | 1 |
| `AppBar` | 1 |
| `MaterialApp` | 1 |
| `Card` | 1 |
| `ElevatedButton` | 1 |
| `CircularProgressIndicator` | 1 |
| `Container` | 1 |
| `Column` | 1 |
| `Padding` | 1 |
| `SizedBox` | 1 |
| `ListView` | 1 |
| `InkWell` | 1 |
| `BackdropFilter` | 1 |
| `CustomPaint` | 1 |

（完整数据见 `widget_inventory.csv`，原始 JSON 见 `widget_inventory.json`）
