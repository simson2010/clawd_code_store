# P0 Kickoff 检查清单

> 用法：P0 阶段（1–2 周）逐项打勾。**打不了勾的 = 阻塞项**，必须升级决策，不要带着进 P1。
> 粗体项 = 有"可能不通"风险，建议第一周就启动。

---

## A. 决策类（不写代码，但返工代价最大）

- [ ] **A1** Bundle ID 确定：全新上架 / 复用现有壳 App 更新
- [ ] **A2** 发布策略：是否需要 App Store 重新审核、老 App 下线时间点、是否需要应用内迁移引导
- [ ] **A3** 账号体系：新 App 与 Flutter 内测版是否共用 SSO；如需重新登录，是否已告知相关方
- [ ] **A4** 服务端 `clientType` / `appVersion` 标识对齐（后端确认）
- [ ] **A5** device token / 推送别名体系是否重建（后端 + 推送平台）
- [ ] **A6** 风控设备指纹：换 Bundle ID 是否触发重判（风控团队确认）
- [ ] **A7** 测试环境产生的脏数据是否清理
- [ ] **A8** **iOS 部署 target 决策**：拿到现有/目标用户的 iOS 版本分布数据 → 决策人签字
- [ ] **A9** 持久化方案定案（SwiftData 不可用）：Core Data / GRDB / SQLite.swift / 纯文件
- [ ] **A10** 网络层归属：复用壳的 / Domain SDK 自带（两套 Token 刷新必炸，必须二选一）

---

## B. 原生壳体检（可继承度矩阵）

对每一项标记：✅ 直接复用 / 🔄 Facade 包装 / ❌ 替换

| 壳的能力 | 结论 | 备注 |
|---|---|---|
| CI / 打包 / 证书 | | 通常最有价值，直接复用 |
| 崩溃 / 性能监控 | | 符号表与版本串是否独立 |
| 配置下发（Kill switch 载体） | | 有就直接用，别新建 |
| 推送通道 | | |
| 网络层 / 拦截器 / Token 刷新 | | 与 A10 联动 |
| 账号 / 登录态 | | 与 A3 联动 |
| 埋点 SDK | | 能否承载新 Tagging |
| Xcode / Swift 版本 | | TCA 需宏 → Xcode 15+；Swift 6 language mode 能否开 |
| 部署 target | | 与 A8 是否冲突 |
| 第三方 SDK 清单 | | 是否有许可证/合规限制 |

- [ ] B 完成，并有书面结论

---

## C. **GenUI 组件映射 POC**（第一周启动，最高不确定性）

- [ ] C1 验证：GenUI 能否把 Figma Component 实例映射到已有 SwiftUI View（`DSButton`），而非展开原始图层
- [ ] C2 验证：映射表能否导出为文件、可否版本化 diff
- [ ] C3 验证：嵌套 Component（两层以上）children 不丢失
- [ ] C4 验证：改 Figma Variable → Design Token 是否跟着变（单向源成立）
- [ ] C5 结论归档，并按结论**重估 P3/P4 工时**

> 若 C1 不通过：GenUI 降级为"布局意图与间距提取"，组件引用改由 Agent 二次替换。工时需上调。

---

## D. Figma 组件 variant 覆盖率审计

对**每一个**参与迁移的 Figma Component：

- [ ] default
- [ ] pressed / highlighted
- [ ] disabled
- [ ] loading / busy
- [ ] selected
- [ ] error / invalid
- [ ] focused
- [ ] 深色模式变体
- [ ] 超长文本（ truncation 行为）
- [ ] 无图 / 图加载失败

- [ ] 缺失清单已提交设计补齐
- [ ] Figma Variables 已梳理，且与 Token 命名一致
- [ ] Auto Layout 覆盖率检查（决定 GenUI 生成 Stack 还是绝对定位）

---

## E. Flutter 侧资产扫描与归档

- [ ] E1 跑 `tools/scan_flutter_widgets.py` → 组件清单 + 风险打标
- [ ] E2 自绘 / `CustomPainter` / `BackdropFilter` / Shader 清单
- [ ] E3 Platform Channel / FFI 清单
- [ ] E4 三方 SDK 清单（广告/推送/地图/支付）
- [ ] E5 是否存在代码热更（Shorebird 等）—— iOS 不允许，若存在需改需求流程
- [ ] E6 埋点事件清单提取（即使不需对齐，仍是 Coverage 检查的输入）
- [ ] E7 **Flutter 仓库转只读归档**（不要删），保留可安装的真机包作为 QA/产品验收参照

---

## F. API 契约

- [ ] F1 是否有 OpenAPI / Swagger？（有则优先，可生成客户端）
- [ ] F2 无则真机抓包跑一遍全流程，导出请求/响应样本
- [ ] F3 错误码与业务 code 枚举提取
- [ ] F4 鉴权方式、Token 刷新规则确认
- [ ] F5 幂等要求（下单/支付类接口）确认

---

## G. Tagging

- [ ] G1 Tagging 文档冻结
- [ ] G2 从文档生成 Swift 枚举的脚本就位
- [ ] G3 CI 接入 generate + diff
- [ ] G4 采样率 / 事件黑名单是否需服务端下发

---

## H. 试点选择

按三个维度各挑一个，必须能一次性暴露管线全部难点：

- [ ] H1 简单列表屏（验基础管线：列表/分页/空态）
- [ ] H2 复杂表单屏（验状态机/校验/提交/错误恢复）
- [ ] H3 自绘或复杂动画屏（验最难映射路径）

---

## P0 出口标准

满足以下三条才允许进 P1：

1. A 类全部有书面决策（不是"待定"）
2. C 类 POC 有明确结论（通过或降级，且工时已重估）
3. D 类 variant 缺失清单已交设计，且阻塞项已补齐
