# GitHub Copilot 连接 Header 分析

## 最终请求 Header 汇总

```
content-type: application/json
User-Agent: opencode/<version>
Authorization: Bearer <github_oauth_token>
x-session-affinity: <sessionID>
x-parent-session-id: <parentSessionID>          ← 仅子代理
x-initiator: agent | user
Openai-Intent: conversation-edits
Copilot-Vision-Request: true                     ← 仅图片请求
anthropic-beta: interleaved-thinking-2025-05-14  ← 仅 Anthropic/Claude 模型
```

## Header 来源分层

### 层 1：传输层

**文件:** `packages/llm/src/protocols/shared.ts:238`

- `content-type: application/json` — 始终存在

### 层 2：通用 LLM 请求层

**文件:** `packages/opencode/src/session/llm/request.ts:168-184`

由于 `github-copilot` 不以 `"opencode"` 开头，使用通用分支：

| Header | Value |
|--------|-------|
| `x-session-affinity` | `<sessionID>` |
| `x-parent-session-id` | `<parentSessionID>`（仅子代理） |
| `User-Agent` | `opencode/<version>` |

### 层 3：plugin `chat.headers` 钩子

**文件:** `packages/opencode/src/plugin/github-copilot/copilot.ts:345-392`

| Header | Condition |
|--------|-----------|
| `anthropic-beta` | `interleaved-thinking-2025-05-14` — 仅 Anthropic SDK 调用 Claude 模型时 |
| `x-initiator` | `"agent"` — 仅 compaction 进行中或 session 是子代理时 |

### 层 4：自定义 `fetch` 拦截器（最终覆盖）

**文件:** `packages/opencode/src/plugin/github-copilot/copilot.ts:150-167`

```typescript
const headers: Record<string, string> = {
  "x-initiator": isAgent ? "agent" : "user",    // 根据最后消息 role 判断
  ...(init?.headers as Record<string, string>),  // 保留上游 header
  "User-Agent": `opencode/${InstallationVersion}`, // 覆盖
  Authorization: `Bearer ${info.refresh}`,        // GitHub OAuth token
  "Openai-Intent": "conversation-edits",           // 始终
}

if (isVision) {
  headers["Copilot-Vision-Request"] = "true"       // 仅含图片
}

delete headers["x-api-key"]        // 删除上游可能的 api key
delete headers["authorization"]    // 删除上游可能的 bearer（小写 key）
```

| Header | Value | 说明 |
|--------|-------|------|
| `x-initiator` | `"agent"` 或 `"user"` | `isAgent` 判断：最后消息非 user role || 含图片附件 → `"agent"` |
| `Openai-Intent` | `conversation-edits` | 始终，标识对话编辑场景 |
| `Copilot-Vision-Request` | `true` | 仅在消息包含图片时 |
| `User-Agent` | `opencode/<version>` | 覆盖上游 |
| `Authorization` | `Bearer <token>` | GitHub OAuth token |

### Copilot 特有 Header 说明

`x-initiator`、`Openai-Intent`、`Copilot-Vision-Request` 是 **Copilot 独有的**。其他 provider（OpenAI、Anthropic 直连）不发送这些字段。

## `x-initiator` 判断逻辑

**文件:** `packages/opencode/src/plugin/github-copilot/copilot.ts:97-148`

```typescript
const { isVision, isAgent } = iife(() => {
  try {
    const body = JSON.parse(init.body)

    // Completions API
    if (body?.messages && url.includes("completions")) {
      const last = body.messages[body.messages.length - 1]
      return {
        isVision: body.messages.some(msg =>
          Array.isArray(msg.content) && msg.content.some(part => part.type === "image_url")
        ),
        isAgent: last?.role !== "user" || imgMsg(last),
      }
    }

    // Responses API
    if (body?.input) {
      const last = body.input[body.input.length - 1]
      return {
        isVision: body.input.some(item =>
          Array.isArray(item?.content) && item.content.some(part => part.type === "input_image")
        ),
        isAgent: last?.role !== "user" || imgMsg(last),
      }
    }

    // Messages API (Anthropic)
    if (body?.messages) {
      const last = body.messages[body.messages.length - 1]
      const hasNonToolCalls = Array.isArray(last?.content) &&
        last.content.some(part => part?.type !== "tool_result")
      return {
        isVision: /* 检查嵌套在 tool_result 中的 image */,
        isAgent: !(last?.role === "user" && hasNonToolCalls) || imgMsg(last),
      }
    }
  } catch {}
  return { isVision: false, isAgent: false }
})
```

## OAuth 认证流程

**文件:** `packages/opencode/src/plugin/github-copilot/copilot.ts:172-327`

1. 使用 Client ID `Ov23li8tweQw6odWQebz` 发起设备授权
2. 请求 scope: `read:user`
3. 轮询 token endpoint，支持 `authorization_pending`、`slow_down` 状态
4. 成功后返回 `refresh` token，用于所有后续 API 调用
5. 支持 GitHub.com 和 GitHub Enterprise（`copilot-api.<domain>`）
