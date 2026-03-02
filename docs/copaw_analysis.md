# CoPaw 项目架构与功能分析文档

> 分析日期：2026-03-02
> 项目地址：https://github.com/agentscope-ai/CoPaw

---

## 1. 项目概述

### 1.1 是什么

**CoPaw** (Co Personal Agent Workstation) 是由 **AgentScope 团队** 开发的一款个人 AI 助手框架。其名字含义：
- **Co Personal Agent Workstation**：个人 AI 助手工作站
- **Co-paw**：象征着一直陪伴在身边的"爪子"，温暖的伙伴

### 1.2 核心理念

- **多渠道支持**：一个助手，连接多种聊天应用
- **本地部署**：数据可控，支持本地或云端部署
- **可扩展技能**：通过 Skills 机制扩展功能
- **定时任务**：内置 cron 支持定时提醒和摘要

### 1.3 应用场景

| 类别 | 功能 |
|------|------|
| **社交** | 小红书、知乎、Reddit 热榜每日摘要，B站/YouTube 视频总结 |
| **生产力** |  Newsletter 摘要推送到钉钉/飞书/QQ，日历/邮件联系人同步 |
| **创意** | 描述目标，彻夜运行，次日获取草稿 |
| **研究** | 科技/AI 新闻追踪，个人知识库 |
| **桌面** | 文件整理，文档阅读总结，聊天中请求文件 |
| **探索** | 结合 Skills 和 cron 构建自己的 Agentic 应用 |

---

## 2. 系统架构

### 2.1 整体架构图

```
┌─────────────────────────────────────────────────────────────┐
│                        CoPaw Core                          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │   Console   │  │   Channels  │  │      Skills         │ │
│  │  (Web UI)   │  │  (多渠道)    │  │    (扩展能力)       │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │   Memory    │  │   Heartbeat │  │   Local Models     │ │
│  │  (记忆管理)  │  │  (定时任务)  │  │  (本地大模型)       │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│                    LLM Provider Layer                       │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐ │
│  │ DashScope│ │ModelScope│ │ llama.cpp│ │     MLX      │ │
│  │ (阿里云)  │ │ (魔搭)   │ │ (跨平台)  │ │ (Apple Silicon)│
│  └──────────┘ └──────────┘ └──────────┘ └──────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 核心组件

#### 2.2.1 Console (Web 控制台)

- **端口**：8088
- **功能**：
  - 与 CoPaw 聊天
  - 配置 AI 模型
  - 管理技能 (Skills)
  - 设置定时任务 (Heartbeat)
  - 管理环境变量

#### 2.2.2 Channels (多渠道支持)

支持的消息平台：

| 渠道 | 说明 |
|------|------|
| **钉钉 (DingTalk)** | 企业/个人钉钉机器人 |
| **飞书 (Feishu)** | 飞书消息收发 |
| **QQ** | QQ 机器人 |
| **Discord** | Discord 服务器机器人 |
| **iMessage** | 苹果消息 |
| **更多...** | 可扩展设计 |

#### 2.2.3 Skills (技能系统)

- **内置技能**：Cron 定时任务
- **自定义技能**：用户可在工作区编写，自动加载
- **无锁定**：完全可控，无厂商锁定

#### 2.2.4 Memory (记忆管理)

- 支持上下文管理
- 长短期记忆分离
- 可配置的记忆策略

#### 2.2.5 Heartbeat (心跳/定时任务)

- 定时检查和推送
- 支持自定义间隔
- 可推送至任意渠道

#### 2.2.6 Local Models (本地模型)

| 后端 | 适用平台 | 安装方式 |
|------|----------|----------|
| **llama.cpp** | 跨平台 (macOS/Linux/Windows) | `pip install 'copaw[llamacpp]'` |
| **MLX** | Apple Silicon (M1-M4) | `pip install 'copaw[mlx]'` |

---

## 3. 部署方式

### 3.1 快速安装 (推荐)

```bash
# pip 安装
pip install copaw
copaw init --defaults
copaw app
```

然后访问 http://127.0.0.1:8088/

### 3.2 一键安装 (无需 Python)

**macOS / Linux:**
```bash
curl -fsSL https://copaw.agentscope.io/install.sh | bash
```

**Windows (PowerShell):**
```powershell
irm https://copaw.agentscope.io/install.ps1 | iex
```

### 3.3 Docker 部署

```bash
docker pull agentscope/copaw:latest
docker run -p 8088:8088 -v copaw-data:/app/working agentscope/copaw:latest
```

### 3.4 云端部署

- **ModelScope Studio**：一键云端配置
- **阿里云 ECS**：一键部署

---

## 4. LLM 提供商支持

### 4.1 云端模型

| 提供商 | 环境变量 | 说明 |
|--------|----------|------|
| **DashScope** | `DASHSCOPE_API_KEY` | 阿里云 LLM 服务 |
| **ModelScope** | `MODELSCOPE_API_KEY` | 魔搭社区 |

### 4.2 本地模型

- 支持 llama.cpp (GGUF 格式)
- 支持 Apple MLX 格式
- 可从 HuggingFace/ModelScope 下载模型

---

## 5. CLI 命令

| 命令 | 功能 |
|------|------|
| `copaw init` | 初始化配置 |
| `copaw init --defaults` | 默认配置初始化 |
| `copaw app` | 启动 Web 服务 |
| `copaw models list` | 列出可用模型 |
| `copaw models download <model>` | 下载模型 |
| `copaw cron` | 管理定时任务 |
| `copaw skills` | 管理技能 |
| `copaw clean` | 清理数据 |

---

## 6. 项目技术栈

### 6.1 后端

- **语言**：Python 3.10+ (≤3.14)
- **框架**：AgentScope Runtime
- **LLM 集成**：DashScope SDK, llama.cpp, MLX

### 6.2 前端

- **Console**：Web UI (Node.js)
- **静态资源**：独立构建

### 6.3 部署

- **Docker**：容器化支持
- **阿里云**：ECS 一键部署

---

## 7. 与 OpenClaw 对比

| 特性 | CoPaw | OpenClaw |
|------|-------|----------|
| **定位** | 个人 AI 助手 | AI Agent 框架 |
| **渠道** | 钉钉/飞书/QQ/Discord/iMessage | 多平台 |
| **技能** | Skills 系统 | Skills + AgentSkills |
| **部署** | 本地/Docker/云端 | 本地部署 |
| **模型** | 云端 + 本地 | 多模型支持 |
| **定时任务** | Heartbeat | Cron |

---

## 8. 总结

CoPaw 是一个功能完善的**个人 AI 助手**框架，特点是：

1. ✅ **开箱即用**：3 命令快速启动
2. ✅ **多渠道覆盖**：国内外主流通讯平台
3. ✅ **本地优先**：支持完全本地部署，无需 API Key
4. ✅ **可扩展**：Skills 机制灵活
5. ✅ **阿里生态**：与 DashScope、ModelScope 深度集成

适合需要**个人 AI 助手**、注重**数据隐私**、喜欢**自托管**的用户。

---

## 9. 参考链接

- GitHub: https://github.com/agentscope-ai/CoPaw
- 文档: https://copaw.agentscope.io/
- Discord: https://discord.gg/eYMpfnkG8h
- 钉钉群: https://qr.dingtalk.com/action/joingroup?code=v1,k1,OmDlBXpjW+I2vWjKDsjvI9dhcXjGZi3bQiojOq3dlDw=
