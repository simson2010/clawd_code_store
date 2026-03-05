# AReaL 仓库分析报告

## 概述

**AReaL** (A Large-Scale Asynchronous Reinforcement Learning System) 是一个开源的大规模异步强化学习训练系统，专门用于训练大型推理模型和智能体模型。

- **开发团队**: 清华大学IIIS + 蚂蚁集团AReaL团队
- **基于**: 开源项目 [ReaLHF](https://github.com/openpsi-project/ReaLHF)
- **官网**: https://inclusionai.github.io/AReaL/
- **论文**: [arXiv:2505.24298](https://arxiv.org/pdf/2505.24298)

---

## 核心能力

### 1. 异步强化学习训练
- **全异步架构**: 业界领先速度的完全异步RL训练
- **2.77倍加速**: 相比同步系统 (boba²版本)
- **简化多轮训练**: 异步架构显著简化了智能体RL训练设置

### 2. 支持的算法

| 算法 | 说明 |
|------|------|
| **GRPO** | Group Relative Policy Optimization |
| **PPO** | Proximal Policy Optimization |
| **DAPO** | Decoupled Clip DAPO |
| **GSPO** | Group Sampling PPO |
| **LitePPO** | 轻量级PPO |
| **Dr.GRPO** | Dense Reward GRPO |
| **REINFORCE++** | 改进版REINFORCE |
| **RLOO** | REINFORCE with Leave-One-Out Baseline |
| **M2PO** | M2PO算法 |
| **SAPO** | Self-Adversarial PPO |

### 3. 支持的模型

- **Qwen2/3** ✅ (Megatron / FSDP / Archon)
- **Qwen3-MoE** ✅
- **Qwen2.5-VL / Qwen3-VL** (视觉语言模型)
- **Gemma 3**
- 其他HuggingFace模型

### 4. 训练后端

- **Megatron**: 支持ZeRO-1、TP、SP、CP、PP、EP、Sequence Packing
- **PyTorch FSDP**: 支持FSDP2、TP、SP、CP、LoRA
- **PyTorch Archon**: 支持完整并行

### 5. 推理后端

- **vLLM**: Tensor Parallel, Pipeline Parallel
- **SGLang**: Tensor Parallel, Data Parallel Attention, Expert Parallel

---

## 应用场景

### 数学推理
- GSM8K数学推理
- 多轮数学智能体
- LoRA高效参数训练
- Countdown数字游戏

### 智能体RL (Agentic RL)
- 通用智能体训练
- Tau2客服智能体 (零售/航空/电信)
- 搜索智能体
- 工具集成推理 (TIR)
- OpenAI Agents SDK集成
- CAMEL-AI集成
- **OpenClaw智能体训练** 🦞

### 视觉语言模型
- Geometry3K / CLEVR视觉推理
- NPU硬件支持

### 对齐与基础设施
- RLHF奖励建模
- SkyPilot云端部署

---

## 性能亮点

- **数学推理**: SOTA 7B/32B模型
- **客服智能体**: 235B MoE模型超越GPT-5，媲美Gemini 3.0 Pro (τ²-bench)
- **搜索智能体**: ASearcher (开源)
- **终端智能体**: CAMEL-AI SETA

---

## 快速开始

```bash
# 安装
git clone https://github.com/inclusionAI/AReaL
cd AReaL
pip install uv
uv sync --extra cuda

# 单节点运行
python3 examples/math/gsm8k_rl.py --config examples/math/gsm8k_grpo.yaml scheduler.type=local

# Ray集群 (2节点，每节点8GPU)
python3 examples/math/gsm8k_rl.py --config examples/math/gsm8k_grpo.yaml \
 cluster.n_nodes=2 cluster.n_gpus_per_node=8 scheduler.type=ray
```

---

## 版本历史

| 版本 | 日期 | 亮点 |
|------|------|------|
| v0.3 (boba²) | 2025/06 | 2.77×加速，完全异步训练 |
| v0.2 (boba) | 2025/03 | SGLang支持，SOTA 7B/32B |
| v0.1 | 2025/02 | 初始版本，1.5B/7B LRMs |
| AReaL-lite | 2025/07 | 轻量版，80%代码减少 |
| AReaL-SEA | 2026/02 | 自演进数据合成引擎 |

---

## 资源链接

- 📖 [文档](https://inclusionai.github.io/AReaL/)
- 📄 [论文](https://arxiv.org/pdf/2505.24298)
- 🤗 [模型与数据](https://huggingface.co/collections/inclusionAI/)
- 💬 [DeepWiki](https://deepwiki.com/inclusionAI/AReaL)

---

## 总结

AReaL是一个功能完整、性能领先的大规模强化学习训练系统，特别擅长:

1. **训练大型推理模型** (Math, Coding, Reasoning)
2. **训练智能体模型** (客服、搜索、工具使用、多轮交互)
3. **异步高效训练** (2.77倍加速)
4. **多硬件支持** (GPU CUDA, NPU)

对于希望训练自己AI智能体的开发者，AReaL提供了开箱即用的解决方案，支持与OpenClaw等主流智能体框架集成。
