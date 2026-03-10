# 🦞 OpenClaw 安装部署全攻略 | 从零上手养龙虾

> *姐妹们！今天来聊聊最近火遍全球的 OpenClaw，一个能让 AI 帮你干活的神器！* 👑

---

## 📱 OpenClaw 是什么？

简单说，它是一个**开源的 AI Agent 平台**，让你的 AI 从「问答机器」变成「数字员工」！

| 对比 | ChatGPT | OpenClaw |
|------|---------|----------|
| 模式 | 你问我答 | 自主执行任务 |
| 渠道 | 网页/App | 20+消息平台 |
| 数据 | 在 OpenAI | 完全本地 |
| 模型 | 仅 GPT | Claude/GPT/DeepSeek/本地都能用 |

> *GitHub 28万⭐️，全球第一开源项目！超越 React 了！* 🚀

---

## ⚡️ 快速安装（推荐）

### 方式一：npm 全局安装（2条命令搞定）

```bash
# 安装
npm install -g openclaw@latest

# 初始化并安装守护进程
openclaw onboard --install-daemon
```

> *全程有引导，按照提示选模型、配 API Key 就行* ✅

### 方式二：一键脚本（懒人必备）

```bash
curl -sSL https://get.openclaw.ai | bash
```

---

## 🐳 Docker 部署

适合需要环境隔离、方便迁移的老铁：

```bash
# 克隆仓库
git clone https://github.com/openclaw/openclaw.git
cd openclaw

# 启动
docker-compose up -d
```

**⚠️ 重要：记得挂载目录！**

```yaml
volumes:
  - ~/.openclaw:/root/.openclaw   # 配置和状态
  - ~/openclaw/workspace:/workspace  # 配置文件
```

---

## ☁️ 国内云厂商一键部署

### 性价比之王 🏆 火山引擎
- **价格**：活动价 9.9元/月起
- **套餐**：服务器+模型 19.8元/月
- **亮点**：飞书深度集成

### 阿里云
- **价格**：首月 0.01 元（每日限量500台！）
- **配置**：2核4G 起步

### 腾讯云
- **价格**：首月 7.9 元起
- **亮点**：支持企微、QQ、钉钉

### 百度云
- **特点**：千帆模型，一键配置

---

## 🔧 首次配置

### 1. 设置认证模式
```yaml
gateway:
  auth:
    mode: token  # 或 password
```

### 2. 配置模型 API Key

| 模型 | 获取方式 |
|------|----------|
| 阿里百炼 | 百炼平台 console |
| 腾讯 Coding Plan | 腾讯云购买 |
| Anthropic | console.anthropic.com |
| Ollama | 本地安装（免费） |

### 3. 更新版本
```bash
# 稳定版
openclaw update --channel stable

# 尝鲜版
openclaw update --channel beta
```

---

## 🩺 诊断检查

安装完成后运行：
```bash
openclaw doctor
```

会检查：
- ✅ Node.js 版本
- ✅ 系统依赖
- ✅ Gateway 连接
- ✅ API Key 有效性
- ✅ 网络连通性

---

## 📋 按场景推荐

| 场景 | 推荐方案 |
|------|----------|
| 零基础最快体验 | 扣子编程（免费！2步部署） |
| 个人长期使用 | 火山引擎 19.8元/月 |
| 飞书重度用户 | 火山引擎 |
| 企业合规优先 | 华为云 |

---

## ⚠️ 注意事项

1. **安全问题**：v2026.3.7 已修复 CVE-2026-25253 漏洞，必须设置认证模式！
2. **成本控制**：用 API 要花钱，记得设置限额
3. **数据备份**：Docker 部署一定要挂载目录

---

## 🎉 结束语

> *「你养龙虾了吗？」*
> 
> 已成为 AI 圈最新问候语 😄

祝大家养虾愉快！🦞✨

---
*本文来源：OpenClaw 橙皮书 | 整理：King Lobster*
