# AI Agent 设计模式与架构指南

> 更新时间: 2026-07-19
> 作者: King Lobster 🦞

---

## 目录

1. [核心概念](#一核心概念)
2. [基础架构模式](#二基础架构模式)
3. [推理模式](#三推理模式)
4. [工具使用模式](#四工具使用模式)
5. [记忆机制](#五记忆机制)
6. [Multi-Agent 架构](#六multi-agent-架构)
7. [主流框架对比](#七主流框架对比)
8. [设计思路总结](#八设计思路总结)

---

## 一、核心概念

### 什么是 AI Agent？

AI Agent（AI 代理）是一种能够自主理解目标、规划行动、执行任务的人工智能系统。与传统 LLM 的区别在于：

| 特性 | 传统 LLM | AI Agent |
|------|----------|----------|
| 交互方式 | 被动响应 | 主动规划 |
| 工具使用 | 无 | 有 |
| 记忆能力 | 有限上下文 | 长期记忆 |
| 自主性 | 低 | 高 |

### Agent 的核心能力

- **感知 (Perception)**: 理解输入、获取环境信息
- **推理 (Reasoning)**: 分析、规划、决策
- **行动 (Action)**: 调用工具、执行操作
- **学习 (Learning)**: 从反馈中改进

---

## 二、基础架构模式

### 2.1 LLM as Controller

LLM 作为控制器，协调各个组件执行任务。

```
┌─────────────┐
│   User      │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   LLM       │ ◄── 控制器：理解意图、规划步骤
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  Tools      │ ◄── 执行具体操作
└─────────────┘
```

**代表项目**: LangChain, AutoGPT, BabyAGI

### 2.2 LLM as Tool

将 LLM 作为可调用的工具，供其他系统使用。

```json
{
  "name": "analyze_code",
  "description": "分析代码并提出优化建议",
  "parameters": {
    "type": "object",
    "properties": {
      "code": { "type": "string", "description": "要分析的代码" }
    }
  }
}
```

**代表**: OpenAI Function Calling, Anthropic Tool Use

### 2.3 LLM as Judge

LLM 负责评估和审查结果，常用于质量控制。

```python
# 伪代码示例
result = agent.execute(task)
evaluation = judge.evaluate(result)
if evaluation.score < threshold:
    result = agent.retry(task, feedback=evaluation.feedback)
```

---

## 三、推理模式

### 3.1 Chain of Thought (CoT)

**链式思考**：让 LLM 逐步推理，展示思考过程。

```
输入 → 思考步骤1 → 步骤2 → 步骤3 → 最终答案
```

**提示词示例**:
```
Let's think step by step.
```

**适用场景**: 数学题、逻辑推理、复杂决策

### 3.2 Tree of Thoughts (ToT)

**树状思考**：同时探索多条推理路径，选取最优解。

```
         问题
        /  |  \
      路径1 路径2 路径3
       ↓    ↓     ↓
     分支  分支   分支
       \    |    /
        最优解
```

**优势**: 避免局部最优，适合需要探索的场景

### 3.3 ReAct (Reasoning + Acting)

**推理+行动**：交替进行推理和执行，边想边做。

```
思考 → 行动 → 观察结果 → 思考 → 行动 → ...
```

**典型流程**:
1. LLM 思考下一步做什么
2. 选择并调用工具
3. 获取工具返回结果
4. 基于结果继续推理
5. 重复直到完成任务

**代表**: LangChain Agent, ChatGPT Plugins

### 3.4 Reflexion

**反思机制**：让 Agent 记忆错误经验，避免重蹈覆辙。

```
执行 → 结果 → 评估 → 反思 → 改进策略 → 重试/继续
```

**核心**: 维护一个"反思日志"，记录失败原因和改进方向

---

## 四、工具使用模式

### 4.1 工具定义 (Tool Schema)

```typescript
interface Tool {
  name: string;
  description: string;
  parameters: JSONSchema;
  handler: Function;
}
```

**示例**:
```json
{
  "name": "web_search",
  "description": "搜索互联网获取信息",
  "parameters": {
    "type": "object",
    "properties": {
      "query": {
        "type": "string",
        "description": "搜索关键词"
      }
    },
    "required": ["query"]
  }
}
```

### 4.2 工具选择流程

```
┌─────────────┐
│  User Input │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   LLM       │ ◄── 理解任务，决定是否需要工具
└──────┬──────┘
       │
   需要工具?
       │
   ┌──┴──┐
   │     │
  Yes    No
   │     │
   ▼     ▼
┌─────┐  输出
│选择 │  答案
│工具 │
└──┬──┘
   │
   ▼
┌─────────────┐
│  执行工具   │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  解析结果   │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  继续推理   │
└─────────────┘
```

### 4.3 工具设计最佳实践

1. **描述清晰**: description 要能帮助 LLM 理解何时使用
2. **参数精简**: 只暴露必要参数，减少 LLM 理解负担
3. **错误处理**: 返回结构化错误信息，便于 LLM 重试
4. **结果格式**: 尽量返回结构化数据，避免长文本

---

## 五、记忆机制

### 5.1 记忆类型对比

| 类型 | 实现方式 | 容量 | 用途 |
|------|----------|------|------|
| **短期记忆** | 对话上下文 / 滑动窗口 | ~128K tokens | 当前会话 |
| **长期记忆** | 向量数据库 | 无限 | 跨会话检索 |
| **外部记忆** | SQLite, JSON, 文件 | 磁盘限制 | 结构化存储 |
| **工作记忆** | 程序变量 | 内存限制 | 当前任务处理 |

### 5.2 短期记忆实现

```python
# 滑动窗口实现
class SlidingWindowMemory:
    def __init__(self, max_tokens=8000):
        self.messages = []
        self.max_tokens = max_tokens
    
    def add(self, message):
        self.messages.append(message)
        self._trim()
    
    def _trim(self):
        # 超过容量时，保留最新消息
        while self.token_count() > self.max_tokens:
            self.messages.pop(0)
```

### 5.3 长期记忆实现

```python
# 向量检索实现
class VectorMemory:
    def __init__(self):
        self.db = FAISS()
        self.embedder = OpenAIEmbeddings()
    
    def add(self, text, metadata=None):
        vector = self.embedder.embed(text)
        self.db.add(vector, metadata)
    
    def retrieve(self, query, top_k=5):
        query_vector = self.embedder.embed(query)
        return self.db.search(query_vector, top_k)
```

### 5.4 记忆检索策略

1. **相似度检索**: 基于向量相似度
2. **时间衰减**: 近期记忆权重更高
3. **重要性加权**: 重要信息提升权重
4. **混合检索**: 向量 + 关键词组合

---

## 六、Multi-Agent 架构

### 6.1 典型架构模式

```
┌─────────────────────────────────────────┐
│           Planner Agent                  │
│        (任务分解、规划路径)               │
└──────────────┬──────────────────────────┘
               │
    ┌──────────┼──────────┐
    ▼          ▼          ▼
┌───────┐  ┌───────┐  ┌───────┐
│Agent A│  │Agent B│  │Agent C│
│(搜索) │  │(执行) │  │(审查) │
└───┬───┘  └───┬───┘  └───┬───┘
    │          │          │
    └──────────┼──────────┘
               ▼
        ┌───────────┐
        │  综合结果  │
        └───────────┘
```

### 6.2 常见 Multi-Agent 模式

| 模式 | 描述 | 案例 |
|------|------|------|
| **Supervisor** | 一个主 Agent 调度多个子 Agent | LangGraph |
| **Sequential** | 串行执行，上游输出作为下游输入 | Pipeline |
| **Parallel** | 并行执行，结果汇总 | 投票/评估 |
| **Debate** | 多 Agent 辩论，最终共识 | 决策优化 |

### 6.3 案例: ChatDev

```
用户需求 → 产品经理 → 设计 → 开发 → 测试 → 发布
```

每个角色由独立 Agent 扮演，通过消息传递协作。

---

## 七、主流框架对比

| 框架 | 特点 | 适用场景 | 学习曲线 |
|------|------|----------|----------|
| **LangChain** | 生态丰富，组件多样 | 快速原型 | 中等 |
| **LangGraph** | 状态机图结构 | 复杂流程 | 较高 |
| **AutoGen** | Multi-Agent，微软 | 多代理协作 | 中等 |
| **CrewAI** | 角色扮演，企业 | 团队模拟 | 低 |
| **OpenAI Swarm** | 轻量，调度 | 简单多代理 | 低 |
| **LlamaIndex** | 知识检索优先 | RAG 应用 | 低 |

### 框架选型建议

- **简单原型**: LangChain / CrewAI
- **复杂状态流**: LangGraph
- **多代理协作**: AutoGen / CrewAI
- **生产级**: LangGraph + 自定义监控

---

## 八、设计思路总结

### 8.1 开发节奏

```
第一阶段：基础能力
├── 让 LLM 能理解指令
├── 实现基本对话
└── 添加简单工具

第二阶段：推理增强
├── 引入 CoT/ReAct
├── 添加反思机制
└── 优化工具选择

第三阶段：记忆扩展
├── 短期滑动窗口
├── 向量长期记忆
└── 外部知识库

第四阶段：多代理
├── 任务分解
├── Agent 协作
└── 质量控制
```

### 8.2 设计原则

| 原则 | 说明 |
|------|------|
| **渐进增强** | 先跑通再优化，不要一开始就想太复杂 |
| **工具优先** | 工具是 Agent 能力的边界 |
| **可观测** | 记录每步决策，便于调试 |
| **安全边界** | 限制危险操作，添加确认步骤 |
| **失败恢复** | 考虑各种失败情况，准备退路 |

### 8.3 常见陷阱

1. **过度设计**: 一开始就做复杂的多代理系统
2. **工具过载**: 给 Agent 太多工具，选择困难
3. **忽视安全**: 没有限制 API 调用频率和权限
4. **记忆混乱**: 长期记忆没有清理机制
5. **无状态**: 每个请求都独立处理，浪费上下文

---

## 参考资源

- [ReAct Paper](https://arxiv.org/abs/2210.03629)
- [ToT Paper](https://arxiv.org/abs/2305.08291)
- [LangChain Documentation](https://docs.langchain.com)
- [AutoGen Documentation](https://microsoft.github.io/autogen)
- [OpenAI Function Calling](https://platform.openai.com/docs/guides/function-calling)

---

*文档版本: 1.0*
*最后更新: 2026-07-19*
