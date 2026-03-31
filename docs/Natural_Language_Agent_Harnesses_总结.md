# Natural-Language Agent Harnesses 论文总结

> **论文标题**: Natural-Language Agent Harnesses  
> **作者**: Linyue Pan 等（清华大学深圳国际研究生院）  
> **发表时间**: 2026年3月（arXiv预印本）  
> **论文链接**: https://arxiv.org/abs/2603.25723

---

## 一、核心概念

### 1.1 问题背景

当前 AI Agent 的**控制逻辑**（harness）通常隐藏在代码中：
- 控制流程硬编码在 Python/JavaScript 中
- 与特定运行时环境强耦合
- 难以移植、比较和科学研究
- 修改控制逻辑需要重新编程

### 1.2 核心创新

论文提出**将控制逻辑外化为自然语言**：

#### **NLAH（Natural-Language Agent Harness）**
- 用**自然语言**描述 Agent 控制逻辑
- 可编辑、可移植、可比较
- 包含：契约、角色、阶段、验证器、状态语义

#### **IHR（Intelligent Harness Runtime）**
- 共享运行时，执行 NLAH
- 内置 LLM 作为解释器
- 提供工具调用、状态持久化、多智能体协作等底层支持

---

## 二、技术架构

### 2.1 IHR 架构（三大核心组件）

```
┌─────────────────────────────────────────┐
│     Intelligent Harness Runtime (IHR)    │
├─────────────────────────────────────────┤
│  1. In-the-loop LLM（解释器）             │
│     - 解析 NLAH 逻辑                     │
│     - 评估环境和状态                     │
│     - 决策下一步行动                     │
├─────────────────────────────────────────┤
│  2. Backend Support（后端支持）           │
│     - 工具调用接口                       │
│     - 子智能体生成与监督                 │
│     - 文件系统和状态管理                 │
├─────────────────────────────────────────┤
│  3. Runtime Charter（运行时章程）        │
│     - 契约定义（输入/输出约束）          │
│     - 状态语义（持久化规则）             │
│     - 多智能体生命周期管理               │
└─────────────────────────────────────────┘
```

### 2.2 NLAH 组成要素

一个完整的 NLAH 必须包含：

| 要素 | 说明 | 示例 |
|---|---|---|
| **契约（Contract）** | 输入/输出约束、前置条件 | 输入必须是 Git repo，输出是修复后的代码 |
| **角色（Roles）** | 智能体角色分工 | 求解器（Solver）、验证器（Validator） |
| **阶段（Stages）** | 控制流程阶段 | 规划 → 执行 → 验证 → 迭代 |
| **适配器（Adapters）** | 确定性操作处理器 | 测试脚本、代码检查器 |
| **状态语义（State Semantics）** | 持久化路径和规则 | 任务历史、工件路径、检查点 |
| **失败分类（Failure Taxonomy）** | 错误处理模式 | 语法错误、运行时错误、验证失败 |

### 2.3 文件支持状态（File-backed State）

**核心思想**：外化状态，确保长周期任务可靠性

```
工作流程：
1. 任务开始 → 创建工作区目录
2. 每个阶段 → 保存工件到文件
3. 失败恢复 → 从文件恢复状态
4. 任务完成 → 归档所有工件
```

**持久化内容**：
- 任务历史（task_history.json）
- 工件路径（artifacts/）
- 检查点（checkpoints/）
- 子智能体状态（sub_agents/）

---

## 三、方法论

### 3.1 从代码到自然语言

**传统方式（代码控制）**：
```python
# 硬编码的控制逻辑
def solve_task(task):
    plan = generate_plan(task)
    for step in plan:
        result = execute(step)
        if not validate(result):
            retry_or_escalate()
    return result
```

**NLAH 方式（自然语言控制）**：
```
契约：
  输入：GitHub issue 描述
  输出：修复后的代码 PR

角色：
  - 求解器：分析问题、生成代码
  - 验证器：运行测试、检查质量

阶段：
  1. 规划：理解问题，制定修复策略
  2. 执行：编写代码，运行测试
  3. 验证：确保测试通过，代码质量达标
  4. 迭代：如失败，分析原因并重试

状态语义：
  - 任务历史保存在 .agent/history.json
  - 代码工件保存在 .agent/artifacts/
```

### 3.2 IHR 执行流程

```
1. 加载 NLAH
   ↓
2. 解析契约和角色
   ↓
3. 进入主循环：
   while not task_complete:
     a. LLM 评估当前状态
     b. 根据阶段规则选择行动
     c. 调用工具或子智能体
     d. 持久化状态到文件
     e. 验证结果
   ↓
4. 返回最终结果
```

---

## 四、实验验证

### 4.1 实验设置

**数据集**：
- **SWE-bench Verified**：125个样本，评估代码修复能力
- **OSWorld**：36个样本，评估桌面自动化任务

**对比基线**：
- TRAE：多候选搜索方法
- Live-SWE：动态编码智能体
- OS-Symphony：计算机使用框架

### 4.2 关键结果

#### RQ1：IHR 对智能体行为的影响

| 配置 | SWE-bench 成功率 | 平均工具调用次数 | 平均运行时间 |
|---|---|---|---|
| Full IHR | 74.4% | 156次 | 12分钟 |
| Ablated（无章程）| 76.0% | 89次 | 7分钟 |

**发现**：
- IHR 增加了工具调用和运行时间
- 但成功率变化有限
- 说明控制逻辑主要影响**行为模式**，而非单纯提升成功率

#### RQ2：模块消融研究

| 模块 | SWE-bench 影响 | OSWorld 影响 | 说明 |
|---|---|---|---|
| 文件支持状态 | **+1.6%** | +2.8% | 提升长周期任务可靠性 |
| 自我进化 | **+4.8%** | +3.1% | 自动优化控制逻辑 |
| 验证器 | -0.8% | **-8.4%** | 过度验证可能降低效率 |
| 多候选搜索 | +0.4% | +1.2% | 效果依赖任务类型 |

**结论**：
- 没有普适有效的模块
- 需根据任务类型选择组合

#### RQ3：代码到自然语言迁移

**OSWorld 任务**：
- 原生代码版 OS-Symphony：**30.4%** 成功率
- NLAH 版 OS-Symphony：**47.2%** 成功率
- 提升 **16.8 个百分点**

**原因分析**：
- NLAH 版本更依赖文件证据和持久化状态
- 减少对屏幕截图的依赖
- 任务关闭更可靠

---

## 五、关键发现

### 5.1 核心贡献

1. **控制逻辑可外化**
   - 自然语言控制套件能达到甚至超越代码版本性能
   - 降低控制逻辑的修改门槛

2. **模块化设计**
   - 可根据任务类型灵活组合模块
   - 文件支持状态、自我进化模块效果显著

3. **降低迁移成本**
   - 从代码到自然语言，无需重新编程
   - 控制逻辑更可读、可调试

4. **科学研究的可行性**
   - NLAH 使控制逻辑成为可研究对象
   - 支持系统性比较和评估

### 5.2 局限性

1. **自然语言模糊性**
   - 可能导致行为不一致
   - 需要精确的契约定义

2. **运行时开销**
   - Token 消耗增加（解释 NLAH）
   - 平均运行时间延长

3. **依赖 LLM 解释能力**
   - 控制逻辑的执行质量取决于 LLM
   - 不同模型可能有不同表现

---

## 六、实践方法

### 6.1 设计 NLAH 控制套件

#### 步骤 1：定义契约
```
契约：
  输入约束：
    - 任务描述（自然语言）
    - 代码库路径（Git repository）
    - 测试命令（bash script）
  
  输出约束：
    - 修复后的代码（diff format）
    - 测试通过证明（test output）
    - 代码质量报告（linting results）
  
  前置条件：
    - 代码库可编译
    - 测试环境可运行
  
  后置条件：
    - 所有测试通过
    - 代码覆盖率 ≥ 80%
```

#### 步骤 2：定义角色
```
角色：
  
  求解器（Solver）：
    职责：分析问题、生成修复代码
    能力：代码理解、测试执行、错误诊断
    限制：最多尝试 3 次
  
  验证器（Validator）：
    职责：确保修复质量
    能力：运行测试、代码审查、性能分析
    限制：必须通过所有测试才能提交
  
  协调器（Coordinator）：
    职责：管理求解器和验证器协作
    能力：任务分配、状态同步、冲突解决
```

#### 步骤 3：定义阶段流程
```
阶段流程：
  
  阶段1：问题理解（Planning）
    输入：任务描述、代码库结构
    输出：修复计划（JSON format）
    持久化：保存计划到 .agent/plan.json
    超时：5 分钟
  
  阶段2：代码修复（Execution）
    输入：修复计划
    输出：修改后的代码文件
    持久化：保存差异到 .agent/patches/
    超时：15 分钟
  
  阶段3：验证（Validation）
    输入：修改后的代码
    输出：测试结果、质量报告
    持久化：保存报告到 .agent/reports/
    超时：10 分钟
  
  阶段4：迭代（Iteration）
    触发条件：验证失败
    行为：分析失败原因，返回阶段2
    最大次数：3 次
```

#### 步骤 4：定义适配器
```
适配器：
  
  测试运行器（Test Runner）：
    类型：确定性脚本
    命令：npm test -- --coverage
    输出：测试结果（JSON）
    失败处理：记录失败用例，返回给求解器
  
  代码检查器（Linter）：
    类型：确定性脚本
    命令：eslint src/ --format json
    输出：问题列表（JSON）
    失败处理：阻塞提交，要求修复
  
  Git 操作器（Git Operator）：
    类型：确定性脚本
    命令：git diff > patch.diff
    输出：差异文件
    失败处理：回滚到上一次提交
```

#### 步骤 5：定义状态语义
```
状态语义：
  
  任务状态（task_state.json）：
    字段：
      - current_stage: string
      - attempts: number
      - last_error: string
      - artifacts: string[]
    更新时机：每个阶段开始和结束时
  
  工件管理（artifacts/）：
    目录结构：
      artifacts/
        ├── plan.json
        ├── patches/
        │   ├── patch_001.diff
        │   └── patch_002.diff
        ├── reports/
        │   ├── test_report_001.json
        │   └── lint_report_001.json
        └── logs/
            └── execution.log
    清理策略：任务完成后保留 7 天
  
  检查点（checkpoints/）：
    触发条件：每个阶段成功完成
    内容：完整的状态快照
    用途：失败恢复
```

#### 步骤 6：定义失败分类
```
失败分类：
  
  类型1：语法错误
    特征：编译失败、解析错误
    处理：返回求解器，提供错误信息
    重试：最多 3 次
  
  类型2：运行时错误
    特征：测试崩溃、超时
    处理：分析堆栈，定位问题代码
    重试：最多 2 次
  
  类型3：验证失败
    特征：测试不通过、代码质量不达标
    处理：返回阶段2，生成新修复
    重试：最多 3 次
  
  类型4：资源限制
    特征：内存不足、磁盘满
    处理：清理临时文件，释放资源
    重试：最多 1 次
  
  类型5：不可恢复错误
    特征：权限错误、网络故障
    处理：终止任务，报告管理员
    重试：不重试
```

---

### 6.2 部署 IHR 运行时

#### 配置运行时章程

**文件**：`runtime_charter.yaml`

```yaml
# 运行时章程
runtime:
  name: "SWE-Agent-IHR"
  version: "1.0.0"
  
  # 权限管理
  permissions:
    file_system: "read_write"
    network: "restricted"  # 仅允许特定域名
    process: "spawn"       # 允许启动子进程
    
  # 资源限制
  limits:
    max_tokens: 100000
    max_tools: 50
    max_runtime: 3600  # 秒
    max_parallel_agents: 3
    
  # 状态管理
  state:
    persistence: "file-backed"
    checkpoint_interval: 300  # 秒
    artifact_retention: 7  # 天
    
  # 多智能体管理
  agents:
    lifecycle: "managed"  # IHR 管理生命周期
    communication: "message_queue"
    supervision: "hierarchical"
    
# 工具注册
tools:
  - name: "code_editor"
    type: "builtin"
    permissions: ["read", "write"]
    
  - name: "test_runner"
    type: "adapter"
    command: "npm test"
    
  - name: "git_client"
    type: "builtin"
    permissions: ["commit", "push", "pull"]
    
# LLM 配置
llm:
  model: "claude-3-opus"
  temperature: 0.2
  max_tokens: 4096
  timeout: 60
  
  # 工具调用模式
  tool_calling:
    mode: "structured"  # 结构化输出
    retry_on_failure: true
    max_retries: 3
```

#### 后端工具库配置

**文件**：`backend_config.yaml`

```yaml
# 后端工具库
backends:
  
  # 文件系统
  filesystem:
    workspace_root: "/tmp/agent_workspace"
    artifact_dir: ".agent"
    temp_dir: "/tmp/agent_temp"
    max_file_size: 100  # MB
    
  # 代码执行
  code_executor:
    sandbox: "docker"  # 使用 Docker 容器
    timeout: 300
    memory_limit: 2048  # MB
    allowed_languages: ["python", "javascript", "bash"]
    
  # Git 操作
  git_manager:
    auto_commit: false
    commit_message_template: "Agent: {task_id}"
    branch_prefix: "agent/"
    
  # 监控和日志
  monitoring:
    log_level: "INFO"
    metrics_export: "prometheus"
    trace_sampling: 0.1  # 10% 采样率
```

---

### 6.3 调试与优化

#### 调试技巧

**1. 直接编辑 NLAH**
```diff
  阶段3：验证（Validation）
-   超时：10 分钟
+   超时：15 分钟  # 给复杂测试更多时间
+   失败处理：
+     - 记录失败的测试用例
+     - 生成诊断报告
+     - 通知求解器优先修复
```

**2. 利用状态文件**
```bash
# 查看当前状态
cat .agent/task_state.json

# 从检查点恢复
cp .agent/checkpoints/checkpoint_3.json .agent/task_state.json

# 查看执行日志
tail -f .agent/logs/execution.log
```

**3. 模块化调试**
```yaml
# 临时禁用验证器，加速测试
modules:
  validator: false
  self_evolution: true
  file_backed_state: true
```

#### 优化策略

**1. 根据任务类型选择模块**

| 任务类型 | 推荐模块组合 | 原因 |
|---|---|---|
| 代码修复 | 文件支持状态 + 自我进化 | 长周期任务，需要可靠性 |
| 快速原型 | 最小配置（无验证器） | 快速迭代，减少开销 |
| 生产部署 | 全模块 + 严格验证 | 确保质量，可追溯性 |
| 交互式任务 | 动态编排 + 多候选搜索 | 应对不确定性，灵活调整 |

**2. Token 优化**
```yaml
# 优化 LLM 配置
llm:
  model: "claude-3-sonnet"  # 更便宜的模型
  max_tokens: 2048          # 减少输出长度
  caching: true              # 启用缓存
  compression: true          # 压缩历史消息
```

**3. 并行化**
```yaml
# 启用并行执行
parallelization:
  enabled: true
  max_workers: 3
  strategy: "fork_join"  # 分叉-合并模式
```

---

## 七、对比分析

### 7.1 与相关工作对比

| 方法 | 控制逻辑表达 | 可移植性 | 可编辑性 | 运行时依赖 |
|---|---|---|---|---|
| **硬编码** | Python/JS | ❌ 低 | ❌ 需重编程 | 特定运行时 |
| **LMQL** | DSL（单次调用） | ⚠️ 中等 | ⚠️ 需学语法 | LMQL 运行时 |
| **DSPy** | Python DSL | ⚠️ 中等 | ⚠️ 需编程 | DSPy 运行时 |
| **AutoHarness** | 自动生成代码 | ⚠️ 中等 | ❌ 需重生成 | 无固定运行时 |
| **NLAH** | 自然语言 | ✅ 高 | ✅ 直接编辑 | IHR 共享运行时 |

### 7.2 优势与权衡

**优势**：
- ✅ 控制逻辑可移植（不依赖特定代码）
- ✅ 可编辑（无需编程技能）
- ✅ 可研究（可比较不同控制策略）
- ✅ 可追溯（状态文件记录完整历史）

**权衡**：
- ⚠️ 运行时开销（Token 消耗增加）
- ⚠️ 自然语言模糊性（需精确契约）
- ⚠️ 依赖 LLM 解释能力（不同模型效果不同）

---

## 八、应用场景

### 8.1 适用场景

1. **自动化编程**
   - Bug 修复（SWE-bench 任务）
   - 代码重构
   - 功能开发

2. **桌面自动化**
   - 文件管理
   - 应用操作
   - 数据处理

3. **多智能体协作**
   - 任务分解
   - 角色分工
   - 结果整合

4. **长周期任务**
   - 研究项目
   - 复杂工作流
   - 持续监控

### 8.2 不适用场景

1. **实时性要求高的任务**
   - 原因：IHR 开销较大
   - 建议：使用硬编码方案

2. **简单单次任务**
   - 原因：NLAH 设计过于复杂
   - 建议：直接使用 LLM API

3. **确定性强的任务**
   - 原因：自然语言增加不确定性
   - 建议：使用传统脚本

---

## 九、未来方向

### 9.1 技术改进

1. **运行时优化**
   - 减少 Token 消耗
   - 提高执行效率
   - 更好的缓存策略

2. **自然语言精确化**
   - 形式化语义定义
   - 自动契约验证
   - 模糊性检测

3. **工具生态**
   - 可视化 NLAH 编辑器
   - 调试工具
   - 性能分析器

### 9.2 研究方向

1. **跨模型迁移**
   - 研究 NLAH 在不同 LLM 上的表现
   - 模型特定的优化策略

2. **标准化**
   - NLAH 标准语法
   - IHR 接口规范
   - 评测基准

3. **应用拓展**
   - 多模态任务
   - 实时交互
   - 人机协作

---

## 十、总结

### 10.1 核心价值

NLAH + IHR 提供了一种**新的 Agent 控制范式**：

```
传统方式：
  控制逻辑 = 代码（硬编码）
  
NLAH 方式：
  控制逻辑 = 自然语言（可编辑）
  执行引擎 = IHR（共享运行时）
```

**带来的改变**：
- 控制逻辑成为**一等公民**（可研究、可比较）
- 降低 Agent 开发门槛（无需编程）
- 提升可维护性（直接编辑自然语言）

### 10.2 实践意义

1. **工程价值**
   - 快速迭代控制逻辑
   - 低成本迁移到不同环境
   - 便于团队协作

2. **研究价值**
   - 控制逻辑可系统比较
   - 支持消融研究
   - 便于复现和验证

3. **商业价值**
   - 降低 Agent 开发成本
   - 提升产品质量（更可靠的控制）
   - 支持定制化（客户可编辑 NLAH）

### 10.3 关键要点

| 维度 | 关键要点 |
|---|---|
| **核心理念** | 控制逻辑外化为自然语言 |
| **技术架构** | NLAH（表达）+ IHR（执行） |
| **关键组件** | 契约、角色、阶段、适配器、状态语义 |
| **实践方法** | 定义契约 → 设计阶段 → 配置 IHR → 调试优化 |
| **适用场景** | 长周期、多步骤、协作型任务 |
| **主要局限** | 运行时开销、自然语言模糊性 |

---

## 参考资料

- **论文原文**: https://arxiv.org/abs/2603.25723
- **代码仓库**: （待发布）
- **相关项目**:
  - LMQL: https://lmql.ai
  - DSPy: https://github.com/stanfordnlp/dspy
  - AutoHarness: （待补充）

---

**生成时间**: 2026-03-31  
**总结者**: Claude (Anthropic)  
**基于**: arXiv:2603.25723v1