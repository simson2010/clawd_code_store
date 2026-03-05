# AReaL 与 OpenClaw/Zeroclaw 集成训练指南

## 概述

本文档详细介绍如何将 AReaL（大规模异步强化学习系统）与 OpenClaw 或 Zeroclaw 集成，通过代理通讯对话来实现强化学习训练。

> **注意**: AReaL 官方示例使用 [Zeroclaw](https://github.com/zeroclaw-labs/zeroclaw)（Rust 编写的轻量级 OpenClaw 替代品），两者集成方式原理相同。

---

## 架构原理

### 训练流程

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐     ┌──────────────┐
│   用户      │────▶│ OpenClaw/   │────▶│  AReaL      │────▶│  训练模型    │
│ (对话)      │     │ Zeroclaw    │     │  Gateway   │     │  (Actor)     │
└─────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
                           │                    │
                           │                    ▼
                           │              ┌──────────────┐
                           │              │ 轨迹收集     │
                           │              │ (对话数据)   │
                           │              └──────────────┘
```

### 核心组件

| 组件 | 作用 |
|------|------|
| **Proxy Gateway** | AReaL 的代理服务，拦截并转发 OpenAI 格式的 API 请求 |
| **Agent Runtime** | OpenClaw 或 Zeroclaw，负责处理用户对话 |
| **轨迹 (Trajectory)** | (输入, 输出, 奖励) 元组，用于 RL 训练 |
| **Actor** | 被训练的模型 |
| **Rollout Worker** | 负责与环境交互生成训练数据 |

---

## 准备工作

### 硬件要求

- **GPU 机器**: 至少 2 张 NVIDIA GPU (Compute Capability ≥ 8.0, Ampere/Hopper 架构)
- **Agent 机器**: 运行 OpenClaw/Zeroclaw，需能通过网络访问 GPU 节点

### 安装 AReaL (GPU 机器)

```bash
# 安装 uv
curl -LsSf https://astral.sh/uv/install.sh | sh

# 克隆 AReaL
git clone https://github.com/inclusionAI/AReaL.git
cd AReaL

# 安装依赖
uv sync --all-extras
```

### 安装 Zeroclaw (Agent 机器)

```bash
git clone https://github.com/zeroclaw-labs/zeroclaw.git
cd zeroclaw
./bootstrap.sh
```

> 如果使用 OpenClaw，原理相同：只需将 API 端点指向 AReaL Gateway 即可。

---

## 配置步骤

### 步骤 1: 启动 AReaL RL 服务

在 GPU 机器上运行：

```bash
uv run python3 examples/openclaw/train.py \
  --config examples/openclaw/config.yaml \
  experiment_name=my-exp \
  trial_name=trial-0 \
  allocation_mode=sglang:d1+fsdp:d1 \
  actor.path=Qwen/Qwen3-0.6B \
  scheduler.type=local \
  rollout.openai.admin_api_key=<your-admin-api-key>
```

启动成功后，会看到类似输出：

```
(AReaL) 20260301-16:30:58.375 RLTrainer INFO: Proxy gateway available at http://x.x.x.x:xx
(AReaL) 20260301-16:30:58.395 ProxyGateway INFO: Proxy gateway starting — 1 backend worker(s): http://x.x.x.x:xx
```

**记录下 Gateway 地址**，后续步骤需要用到。

### 步骤 2: 创建 RL Session

```bash
python start_session.py http://<gateway-address> --admin-key <admin-api-key>
```

输出示例：

```
✔ Session started!
 → Session ID : demo-task-0
 → API Key : sk-sess-xxxxxxxxxxxx
```

这个 `sk-sess-xxxxxxxx` 就是 session API key，用于后续对话。

### 步骤 3: 配置 Agent (Zeroclaw/OpenClaw)

编辑 `~/.zeroclaw/config.toml`（Zeroclaw）或 OpenClaw 配置文件：

```toml
# Zeroclaw 配置示例

# 代理 Gateway 地址
default_provider = "localhost"

# 使用的模型
default_model = "Qwen/Qwen3-0.6B"
default_temperature = 0.7

# Session API Key (来自步骤2)
api_key = "sk-sess-xxxxxxxxxxxx"

[model_providers.localhost]
name = "localhost"
base_url = "http://<gateway-address>"  # AReaL Gateway 地址
wire_api = "chat_completions"
```

如果使用 OpenClaw，需设置环境变量：

```bash
export OPENAI_BASE_URL=http://<gateway-address>
export OPENAI_API_KEY=sk-sess-xxxxxxxxxxxx
```

### 步骤 4: 配置通讯渠道（可选）

Zeroclaw 支持多种渠道（Discord, Slack, Telegram, CLI 等），可按需配置：

```toml
[channels.discord]
enabled = true
token = "your-discord-bot-token"
channel_ids = ["123456789"]

[channels.telegram]
enabled = true
bot_token = "your-telegram-bot-token"
```

---

## 训练流程

### 完整流程图

```
┌─────────────────────────────────────────────────────────────────┐
│                      初始化阶段                                  │
├─────────────────────────────────────────────────────────────────┤
│  1. 启动 AReaL (GPU)                                            │
│  2. 创建 Session → 获取 sk-sess-xxxx                            │
│  3. 配置 Agent 指向 Gateway                                      │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      对话收集阶段                                 │
├─────────────────────────────────────────────────────────────────┤
│  4. Agent 与用户对话                                             │
│  5. Gateway 拦截并记录完整轨迹                                   │
│  6. 达到 batch 数量后自动开始训练                               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      训练阶段                                    │
├─────────────────────────────────────────────────────────────────┤
│  7. 异步强化学习训练 (GRPO/PPO/DAPO 等)                         │
│  8. 模型权重更新                                                 │
│  9. 保存 Checkpoint                                             │
└─────────────────────────────────────────────────────────────────┘
```

### 开始新的 Episode

每次对话回合（episode）结束后，启动新 session 继续收集：

```bash
python start_session.py http://<gateway> --admin-key <admin-api-key> \
  --api-key sk-sess-xxxxxxxxxxxx
```

如果 `--api-key` 已存在，Gateway 会：
1. 自动结束旧 session
2. 导出轨迹数据
3. 开启新 session

无需重新配置 Agent。

---

## 配置参数详解

### 核心配置 (config.yaml)

```yaml
# 实验名称
experiment_name: online-rl
trial_name: trial0

# 资源分配 (SGLang + FSDP)
allocation_mode: sglang:d1 + fsdp:d1

# 调度器
scheduler:
  type: local  # 单节点; 集群用 ray

# Rollout 配置
rollout:
  max_concurrent_rollouts: 256   # 最大并发数
  max_head_offpolicyness: 2      # 异步训练，离 policy 多远
  openai:
    mode: online                 # 在线模式
    admin_api_key: sk-test123456 # 管理密钥

# Actor (被训练模型)
actor:
  path: Qwen/Qwen2.5-1.5B-Instruct  # 模型路径
  optimizer:
    lr: 1.70e-5                     # 学习率
  eps_clip: 0.4                    # PPO clip 参数

# 数据集
train_dataset:
  batch_size: 4
  type: rl

# 训练轮数
total_train_epochs: 10
total_train_steps: 100
```

### 奖励设计

AReaL 支持自定义奖励函数。在 agentic RL 中，可通过以下方式定义奖励：

1. **规则奖励**: 基于对话结果规则
2. **模型奖励**: 使用奖励模型评分
3. **人工反馈**: RLHF/HF 方式

具体参考 [自定义 Agent Workflow](https://github.com/inclusionAI/AReaL/blob/main/docs/customization/agent.md)

---

## 常见问题

### Q: 可以直接用 OpenClaw 吗？

可以。AReaL 的 Gateway 使用 OpenAI Chat Completions 协议，OpenClaw 完全兼容。只需将 `OPENAI_BASE_URL` 和 `OPENAI_API_KEY` 指向 AReaL Gateway 即可。

### Q: 训练需要多少 GPU？

官方示例使用 2+ GPU。实际需求取决于：
- 模型大小
- batch size
- 并发数

### Q: 支持哪些训练算法？

AReaL 支持：GRPO, PPO, DAPO, GSPO, LitePPO, Dr.GRPO, REINFORCE++, RLOO, M2PO, SAPO 等。

### Q: 如何自定义奖励？

编辑 `config.yaml` 中的 `reward_function` 或编写自定义 Python 模块。

### Q: 训练数据保存在哪？

默认保存在 `${cluster.fileroot}/rollouts/` 目录下。

---

## 性能优化建议

1. **调整并发数**: `max_concurrent_rollouts` 可提高数据收集速度
2. **异步训练**: 设置 `max_head_offpolicyness > 0` 启用异步模式
3. **LoRA 微调**: 对大模型使用 LoRA 减少显存占用
4. **梯度累积**: 通过 `gradient_accumulation_steps` 处理大 batch

---

## 参考资源

- [AReaL 官方仓库](https://github.com/inclusionAI/AReaL)
- [Zeroclaw 仓库](https://github.com/zeroclaw-labs/zeroclaw)
- [OpenClaw 仓库](https://github.com/openclaw/openclaw)
- [Agentic RL 教程](https://inclusionai.github.io/AReaL/tutorial/agentic_rl.html)
- [论文: arXiv:2505.24298](https://arxiv.org/pdf/2505.24298)

---

## 总结

通过 AReaL 的 Proxy Gateway，我们可以轻松地将 OpenClaw/Zeroclaw 的对话流量代理到 RL 训练系统，实现：

1. **无缝集成**: 无需修改 Agent 代码
2. **实时训练**: 异步收集对话，自动批量训练
3. **灵活扩展**: 支持多种算法、模型、硬件
4. **开箱即用**: 官方提供完整示例

这套架构特别适合希望基于真实用户对话数据来训练/微调 AI 智能体的开发者。
