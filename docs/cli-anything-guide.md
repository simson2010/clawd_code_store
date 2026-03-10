# 🦞 CLI-Anything 完全指南 | 让所有软件变成 AI Agent 的工具

> *今天来认识一个超强的开源项目——CLI-Anything！它能让任何软件变成 AI Agent 可控的工具* 👑

---

## 🎯 CLI-Anything 是什么？

**一句话解释**：用一条命令，把任何软件变成 AI Agent 可用的 CLI 工具！

> 今天的软件服务于人类 👨‍💻
> 明天的用户将是 AI Agent 🤖

---

## 🤔 为什么 CLI 这么重要？

AI Agent 很会推理，但**不会用真正的专业软件**！

| 传统方式 | CLI-Anything |
|----------|--------------|
| 🤖 AI 无法使用专业工具 | 直接集成真实软件后端（Blender、LibreOffice） |
| 💸 UI 自动化经常崩溃 | 无截图、无点击，纯命令行可靠性 |
| 📊 Agent 需要结构化数据 | 内置 JSON 输出 |
| 🔧 定制集成成本高 | 一条命令自动生成 CLI |
| ⚡ 原型 vs 生产差距 | 1436+ 测试验证 |

---

## 🚀 快速开始

### 前提条件
- Claude Code（需插件支持）
- Python 3.10+
- 目标软件已安装（如 GIMP、Blender、LibreOffice）

### 步骤 1：添加 Marketplace
```bash
/plugin marketplace add HKUDS/CLI-Anything
```

### 步骤 2：安装插件
```bash
/plugin install cli-anything
```

### 步骤 3：一条命令生成 CLI！
```bash
# 为 GIMP 生成完整 CLI
/cli-anything ./gimp
```

这会运行完整的 7 阶段流程：
1. 🔍 **分析** — 扫描源码，映射 GUI 动作到 API
2. 📐 **设计** — 设计命令组、状态模型、输出格式
3. 🔨 **实现** — 构建 Click CLI，支持 REPL、JSON 输出、撤销/重做
4. 📋 **计划测试** — 创建单元测试 + E2E 测试计划
5. 🧪 **编写测试** — 实现完整测试套件
6. 📝 **文档** — 更新测试结果
7. 📦 **发布** — 创建 setup.py，安装到 PATH

### 步骤 4：使用 CLI
```bash
# 安装到 PATH
cd gimp/agent-harness && pip install -e .

# 随时使用
cli-anything-gimp --help
cli-anything-gimp project new --width 1920 --height 1080 -o poster.json
cli-anything-gimp --json layer add -n "Background" --type solid --color "#1a1a2e"

# 进入交互式 REPL
cli-anything-gimp
```

---

## ✨ 支持的应用领域

| 类别 | 示例 |
|------|------|
| 🎨 创意媒体 | **GIMP**, **Blender**, **Inkscape**, Audacity, OBS Studio, Kdenlive, Shotcut |
| 📊 数据分析 | JupyterLab, Apache Superset, Metabase, DBeaver, KNIME |
| 🤖 AI/ML 平台 | Stable Diffusion WebUI, ComfyUI, InvokeAI, Fooocus, Kohya_ss |
| 💻 开发工具 | Jenkins, Gitea, Portainer, pgAdmin, SonarQube, ArgoCD |
| 🏢 企业办公 | **LibreOffice**, NextCloud, GitLab, Grafana, Mattermost |
| 📐 图表工具 | **Draw.io**, Mermaid, PlantUML, Excalidraw |
| 🔬 科学计算 | ImageJ, FreeCAD, QGIS, ParaView, Gephi |

---

## 📊 测试结果

| 软件 | 测试数量 | 状态 |
|------|---------|------|
| 🎨 GIMP | 107 | ✅ 通过 |
| 🧊 Blender | 208 | ✅ 通过 |
| ✏️ Inkscape | 202 | ✅ 通过 |
| 🎵 Audacity | 161 | ✅ 通过 |
| 📄 LibreOffice | 158 | ✅ 通过 |
| 📹 OBS Studio | 153 | ✅ 通过 |
| 🎞️ Kdenlive | 155 | ✅ 通过 |
| 🎬 Shotcut | 154 | ✅ 通过 |
| 📐 Draw.io | 138 | ✅ 通过 |
| **总计** | **1,436** | **100% 通过率** |

---

## 🎯 能做什么？

### 🛠️ 让 Agent 接管你的工作流
专业或日常软件——只要把代码库扔给 `/cli-anything`！
- GIMP、Blender、Shotcut 做创意工作
- LibreOffice、OBS Studio 处理日常任务

### 🔗 把分散的 API 统一成一个 CLI
厌倦了零散的 web 服务 API？把文档喂给 `/cli-anything`，你的 Agent 就能用统一的 CLI 来调用！

### 🚀 替代或增强 GUI Agent
不再需要截图、不再脆弱的像素点击——直接用代码控制！

---

## 🏗️ 架构亮点

- **真实软件集成** — 生成有效项目文件，委托给真实应用渲染
- **双重交互模式** — 有状态的 REPL + 子命令接口
- **统一用户体验** — 所有 CLI 共享 REPL 界面
- **Agent 原生设计** — 内置 --json 标志提供结构化数据
- **零妥协依赖** — 真实软件是硬性要求

---

## 📦 安装方式二选一

### 方式一：Marketplace（推荐）
```bash
/plugin marketplace add HKUDS/CLI-Anything
/plugin install cli-anything
```

### 方式二：手动安装
```bash
git clone https://github.com/HKUDS/CLI-Anything.git
cp -r CLI-Anything/cli-anything-plugin ~/.claude/plugins/cli-anything
/reload-plugins
```

---

## 🔗 资源链接

- GitHub: https://github.com/HKUDS/CLI-Anything
- 中文文档: https://github.com/HKUDS/CLI-Anything/blob/main/README_CN.md

---

## 💡 总结

> **一条命令 = 任何软件变成 AI Agent 工具**

无论是你自己写的应用，还是 GIMP、Blender 这样的专业软件，都能通过 CLI-Anything 变成 Agent 可控的工具。

**1436 个测试 100% 通过**，生产级可用！

---

*🦞 整理自 CLI-Anything GitHub 仓库*
