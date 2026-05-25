# OpenCode LLM 请求/响应架构

## 项目结构

TypeScript monorepo（Bun + Turborepo），核心包：

| 包 | 路径 | 职责 |
|---|---|---|
| `@opencode-ai/llm` | `packages/llm/` | LLM 抽象层：协议、Provider、传输、Schema |
| `@opencode-ai/opencode` | `packages/opencode/` | CLI 应用层，消费 LLM 包 |

## 两条请求路径

### 路径 1：AI SDK（默认）

使用 Vercel AI SDK `streamText()`，动态加载 provider 包（`@ai-sdk/anthropic`、`@ai-sdk/openai` 等）。AI SDK 事件通过 `LLMAISDK.toLLMEvents()` 转换为通用 `LLMEvent`。

**入口:** `packages/opencode/src/session/llm.ts:272-340`

### 路径 2：Native LLM（实验性）

直接使用 `@opencode-ai/llm`，绕过 AI SDK。将应用数据转换为 `LLMRequest`，然后调用 `LLMClient.stream()`。

**入口:** `packages/opencode/src/session/llm/native-runtime.ts:66-102`

## 核心抽象：Route

```typescript
interface Route<Body, Prepared> {
  id: string
  provider?: ProviderID
  protocol: ProtocolID     // 什么 API 形态？
  endpoint: Endpoint<Body> // 发到哪里？
  auth: Auth               // 如何认证？
  transport: Transport     // 如何收发字节？
  defaults: RouteDefaults  // 默认参数
  body: RouteBody<Body>    // 请求体构建 + Schema
}
```

Route 将四个正交维度组合在一起：Protocol、Endpoint、Auth、Framing。

## 支持的协议

| 协议 | 文件 | 线格式 |
|------|------|--------|
| OpenAI Chat | `protocols/openai-chat.ts` | SSE，基于 delta 的工具调用流 |
| OpenAI Responses | `protocols/openai-responses.ts` | SSE，Responses API 格式 |
| OpenAI Compatible Chat | `protocols/openai-compatible-chat.ts` | 复用 OpenAIChat 协议 |
| Anthropic Messages | `protocols/anthropic-messages.ts` | SSE，content blocks |
| Gemini | `protocols/gemini.ts` | SSE，URL 中嵌入 model ID |
| Bedrock Converse | `protocols/bedrock-converse.ts` | AWS 二进制 event-stream |

## 支持的 Provider

Anthropic、OpenAI、Google/Gemini、Amazon Bedrock、Azure、Cloudflare、OpenAI Compatible、OpenRouter、XAI、GitHub Copilot

每个 provider 暴露 `configure(options)` → `{id, model(id)}`。

## 完整请求流程

```
LLM.run() → 解析 provider/model
  → 构建 messages/tools → LLMRequest
  → route.body.from(request) → provider 原生 JSON body
  → Auth headers 注入 → HTTP POST
  → 响应流 → framing（SSE / 二进制 event-stream）
  → 协议状态机 → LLMEvent 流
  → 工具调用循环（如有）→ 递归
  → LLMResponse（.text, .reasoning, .toolCalls, .usage）
```

### 请求构建（"Lowering"）

每个协议有 `fromRequest()` 将 `LLMRequest` 转为 provider 原生 body：

| 协议 | 文件 | 行号 |
|------|------|------|
| OpenAI Chat | `protocols/openai-chat.ts` | 259 |
| Anthropic Messages | `protocols/anthropic-messages.ts` | 431 |
| Gemini | `protocols/gemini.ts` | 257 |
| Bedrock Converse | `protocols/bedrock-converse.ts` | 353 |

### 响应解析

事件类型（`schema/events.ts:206`）：
`step-start/finish`、`text-start/delta/end`、`reasoning-start/delta/end`、
`tool-input-start/delta/end`、`tool-call`、`tool-result`、`tool-error`、`finish`、`provider-error`

每个协议有状态机：`initial()` → `step(state, event)` → `onHalt(state)`

工具调用跨 delta 累积通过 `protocols/utils/tool-stream.ts` 的 `ToolStream` 实现。
