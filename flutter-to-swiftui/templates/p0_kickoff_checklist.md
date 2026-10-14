# P0 Kickoff 检查清单

> 用法：P0 阶段（约 1 周，组件库已就绪故压缩）逐项打勾。**打不了勾的 = 阻塞项**，必须升级决策，不要带着进 P1。
> 本清单与《00-方案V4-暂定最终版》§8 P0 / §10 待决策清单一一对应。
> ⭐ = 有"可能不通"风险或可能推翻技术选型，第一周就启动。

---

## A. 决策类（不写代码，但返工代价最大）

> Bundle ID（相同、覆盖安装）与网络层（复用自建网络库）已定案，不再列为待决项。

- [ ] **A1** ⭐ **组件库 iOS 部署 target 确认** —— 若要求 iOS 17 与 iOS 16 基线直接冲突，唯一可能推翻技术选型的信息
- [ ] **A2** ⭐ 组件库 & 网络库是否 Swift 6 / Sendable ready → 决定 Swift 5/6 language mode（影响全项目代码风格，早定）
- [ ] **A3** 网络库四项能力盘点：async 接口 / 请求取消 / Token 刷新并发合并 / mock 能力 —— 缺哪块 SDK 补哪块
- [ ] **A4** iOS 16 基线数据支撑：目标用户 iOS 版本分布 → 决策人签字（不默认）
- [ ] **A5** 持久化方案定案（SwiftData 不可用）：Core Data / GRDB / 纯文件
- [ ] **A6** 版本号排期：Native 版 > Flutter 最后版；回滚版 > Native 版；Build 号单调递增
- [ ] **A7** 窗口期新需求分流规则写进项目章程（Flutter 端只做必修，新功能一律不做）
- [ ] **A8** API versioning 上线时间（最好 Flutter 首发就带 clientType + version header）
- [ ] **A9** Flutter 导出代码排进哪个版本（至少提前两个版本带上）
- [ ] **A10** 身份连续性六项一次对齐会定死：SSO 是否共用 / clientType / device token 与推送别名 / 风控重判 / 内测脏数据 / 停止支持旧版的时间点

---

## B. 原生壳体检（可继承度矩阵）

对每一项标记：✅ 直接复用 / 🔄 Facade 包装 / ❌ 替换

| 壳的能力 | 结论 | 备注 |
|---|---|---|
| CI / 打包 / 证书 | | 通常最有价值，直接复用 |
| 崩溃 / 性能监控 | | 符号表与版本串是否独立 |
| 配置下发（Kill switch 载体） | | 有就直接用，别新建 |
| 推送通道 | | 与 A10 联动 |
| 网络层 / 拦截器 / Token 刷新 | | 已由"复用自建网络库"定案，此处确认接入方式 |
| 账号 / 登录态 | | 与 A10 联动 |
| 埋点 SDK | | 能否承载新 Tagging |
| Xcode / Swift 版本 | | TCA 需宏 → Xcode 15+；与 A2 联动 |
| 部署 target | | 与 A4 是否冲突 |
| 第三方 SDK 清单 | | 是否有许可证/合规限制 |

- [ ] B 完成，并有书面结论

---

## C. ⭐ 组件库接入确认（替代原 GenUI 组件映射 POC）

> GenUI 已确认为自建、绑定内部组件库 + TCA，原 POC 风险消除。改为对共享组件库的治理性确认：

- [ ] C1 ⭐ 组件缺口三态清单：拿 Flutter 视觉/Figma 逐屏对组件库 → 「库有 / 库缺 / 语义不同」，缺口的尽早提需（越晚提越卡 P4）
- [ ] C2 依赖接入方式确认（SPM / CocoaPods / monorepo）
- [ ] C3 版本发布节奏、changelog、升级政策确认（锁版本 + 显式升级的治理基础）
- [ ] C4 提需求流程与实际 SLA（对口人、响应时长）
- [ ] C5 是否有 preview catalog / Demo App（有则免费得到 snapshot baseline）
- [ ] C6 Token 输入源确认（Figma Variables？独立仓库？）—— 复用，不重建
- [ ] C7 深色 / Dynamic Type / RTL / VoiceOver 覆盖情况（库已内置则 P4 省一大块）
- [ ] C8 硬规则入开发规范：**本地禁止 fork 组件库**（扩展配置 → 提需求 → 本地薄包装）

---

## D. ⭐ GoldenExamples 语料库（全线 ROI 最高，1 人 3 天）

- [ ] D1 ⭐ 拿到其它线上 App 源码的阅读权限（尽早开口）
- [ ] D2 抽 20–30 个内部 TCA Feature 建 `GoldenExamples/`
- [ ] D3 提炼命名约定 / Effect 写法 / 错误处理 / 依赖注册 / 测试写法 → `AGENT_RULES.md`
- [ ] D4 内部 lint / 架构规则清单，接入 Reviewer Agent
- [ ] D5 从带测试的 Feature 生成 `TestStore` 测试范式

---

## E. GenUI 产线验证

- [ ] E1 ⭐ GenUI Figma 覆盖矩阵：哪些图层/特效/交互生成不了 → 手工区集中清单
- [ ] E2 ⭐ 再生/手写隔离方案定稿，且**拿到 GenUI 团队的配合承诺**（输出目录不出现 ❌ 类文件）
- [ ] E3 三层 State 方案（view + domain）在 1 个屏上验证可行
- [ ] E4 CI 守护规则落地：GenUI 输出目录出现逻辑层文件直接报错
- [ ] E5 Figma 标注规范定稿：数据绑定 / 文案 key / accessibility / 状态 variant 命名

---

## F. Figma 组件 variant 覆盖率审计

对**每一个**参与迁移的 Figma Component：

- [ ] default / pressed / disabled / loading / selected / error / focused
- [ ] 深色模式变体
- [ ] 超长文本（truncation 行为）
- [ ] 无图 / 图加载失败

- [ ] 缺失清单已提交设计补齐
- [ ] Figma Variables 已梳理，且与 Token 命名一致
- [ ] Auto Layout 覆盖率检查（决定 GenUI 生成 Stack 还是绝对定位）
- [ ] 组件化检查（重复元素必须是 Component，不是复制图层）

---

## G. Flutter 侧资产扫描与归档

- [ ] G1 跑 `tools/scan_flutter_widgets.py` → 组件清单 + 风险打标
- [ ] G2 自绘 / `CustomPainter` / `BackdropFilter` / Shader 清单
- [ ] G3 Platform Channel / FFI 清单
- [ ] G4 三方 SDK 清单（广告/推送/地图/支付）
- [ ] G5 是否存在代码热更（Shorebird 等）—— iOS 不允许，若存在需改需求流程
- [ ] G6 埋点事件清单提取（Dart 侧全量，供三方映射与 CI 断言）
- [ ] G7 Spec 基线版本号选定，写进 `SPEC_BASELINE.md`
- [ ] G8 Flutter 仓库转只读归档（不要删），保留可安装的真机包作为 QA/产品验收参照

---

## H. API 契约

- [ ] H1 是否有 OpenAPI / Swagger？（有则优先，可生成客户端）
- [ ] H2 无则真机抓包跑一遍全流程，导出请求/响应样本
- [ ] H3 错误码与业务 code 枚举提取
- [ ] H4 鉴权方式、Token 刷新规则确认
- [ ] H5 幂等要求（下单/支付类接口）确认

---

## I. Tagging

- [ ] I1 Tagging 文档冻结
- [ ] I2 从文档生成 Swift 枚举的脚本就位
- [ ] I3 CI 接入 generate + diff
- [ ] I4 采样率 / 事件黑名单是否需服务端下发
- [ ] I5 Flutter ↔ Tagging ↔ Native 三方映射表启动（G6 输出为输入）

---

## J. 迁移数据清单

- [ ] J1 迁移内容清单经产品确认（含「未完成业务状态」：购物车草稿、未提交表单等）
- [ ] J2 各类数据的迁移方式标注（UserDefaults 直接读 / Keychain / 走导出）
- [ ] J3 迁移埋点方案（成功率、失败原因分布必须上报）

---

## K. 试点选择

按三个维度各挑一个，必须能一次性暴露管线全部难点（别挑最简单的三个）：

- [ ] K1 简单列表屏（验基础管线：列表/分页/空态）
- [ ] K2 复杂表单屏（验状态机/校验/提交/错误恢复）
- [ ] K3 自绘或复杂动画屏（验最难映射路径）

---

## P0 出口标准

满足以下四条才允许进 P1：

1. A 类全部有书面决策（不是"待定"），**其中 A1 必须明确无冲突**
2. C1 缺口清单已产出并提需；D 类语料库已建成
3. E2 拿到 GenUI 团队书面配合承诺；E1 覆盖矩阵有结论
4. J1 迁移数据清单经产品签字
