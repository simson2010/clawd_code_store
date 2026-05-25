# User-Agent Header 重写分析

## 普通 Provider（非 Copilot）：可以重写

**文件:** `packages/opencode/src/session/llm/request.ts:168-184`

```typescript
headers: {
  ...(base headers including "User-Agent": USER_AGENT),  // 层1: base
  ...input.model.headers,                                  // 层2: model
  ...headers,  // ← chat.headers 插件输出，在最后展开            // 层3: plugin
},
```

V1 插件的 `"chat.headers"` 钩子（`packages/plugin/src/index.ts:256`）由于位于展开顺序的**最后**，可以覆盖前面设置的 `User-Agent`：

```typescript
// 示例：外部插件重写 User-Agent
export async function myPlugin(input: PluginInput): Promise<Hooks> {
  return {
    "chat.headers": async (input, output) => {
      output.headers["User-Agent"] = "my-custom-agent/1.0"
    },
  }
}
```

## GitHub Copilot：无法通过 Hook 重写

**文件:** `packages/opencode/src/plugin/github-copilot/copilot.ts:150-153`

Copilot 内置插件的自定义 `fetch` 函数在所有请求发出前拦截，**硬编码** `User-Agent`：

```typescript
const headers: Record<string, string> = {
  "x-initiator": isAgent ? "agent" : "user",
  ...(init?.headers as Record<string, string>),  // ← 包含 chat.headers 输出
  "User-Agent": `opencode/${InstallationVersion}`, // ← 在后面，必定覆盖
  Authorization: `Bearer ${info.refresh}`,
  "Openai-Intent": "conversation-edits",
}
```

由于 `"User-Agent"` 在 `...(init.headers)` **之后**展开，**无论 `chat.headers` 钩子设置什么值，都会被覆盖**。

## 执行时序

```
request.ts 组装 headers
  └→ chat.headers 钩子触发（可修改 User-Agent）  ← 对普通 provider 有效
      └→ 传给 AI SDK
          └→ Copilot 自定义 fetch 拦截
              └→ 硬编码 User-Agent 覆盖           ← 对 Copilot 最终覆盖
```

## 绕过方案

| 方案 | 可行性 | 说明 |
|------|--------|------|
| `--disable-default-plugins` + 自定义 Copilot auth 插件 | 可行 | 完全替换内置 Copilot 插件 |
| 直接修改 `packages/opencode/src/plugin/github-copilot/copilot.ts:153` | 直接 | 仅本地有效，不适合分发 |
| 给 opencode 提 PR 让 User-Agent 可通过环境变量或配置覆盖 | 理想 | 需上游接受 |
| 外部插件 `chat.headers` 钩子 | **无效（Copilot）** | fetch 层会覆盖 |

## 可用 Hook 清单

### V1 Plugin Hooks（`packages/plugin/src/index.ts`）

| Hook | 用途 | 能否影响 Header？ |
|------|------|-------------------|
| `chat.headers` | 修改 LLM 请求 header | **是** — 对非 Copilot provider |
| `chat.params` | 修改 LLM 参数（temperature、topP 等） | 否 |
| `chat.message` | 新消息到达时触发 | 否 |
| `experimental.chat.system.transform` | 修改 system prompt | 否 |
| `experimental.chat.messages.transform` | 修改消息列表 | 否 |
| `tool.definition` | 修改工具定义 | 否 |
| `tool.execute.before` | 工具执行前 | 否 |
| `tool.execute.after` | 工具执行后 | 否 |
| `permission.ask` | 权限询问 | 否 |
| `command.execute.before` | 命令执行前 | 否 |
| `shell.env` | Shell 环境变量 | 否 |
| `event` | 事件总线 | 否 |
| `config` | 配置变更 | 否 |
| `auth` | 认证（OAuth / API key） | 可注入自定义 fetch |
| `provider` | Provider 模型发现 | 否 |

### V2 Plugin Hooks（`packages/core/src/plugin.ts`）

| Hook | 用途 | 能否影响 Header？ |
|------|------|-------------------|
| `catalog.transform` | 目录转换 | 否 |
| `account.switched` | 账户切换 | 否 |
| `aisdk.language` | 替换语言模型 | 否 |
| `aisdk.sdk` | 替换 SDK 包 | 否 |
| `agent.update` | Agent 更新拦截 | 否 |
| `agent.remove` | Agent 删除拦截 | 否 |
| `agent.default` | 默认 Agent | 否 |
