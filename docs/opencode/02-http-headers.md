# OpenCode HTTP 请求 Header 分析

## Header 组装层级

Header 从四个层级组装，按顺序应用：

### 层 1：传输层（始终存在）

**文件:** `packages/llm/src/protocols/shared.ts:238-242`

```typescript
HttpClientRequest.setHeaders(
  Headers.set(Headers.fromInput(input.headers), "content-type", "application/json")
)
```

| Header | Value | 来源 |
|--------|-------|------|
| `content-type` | `application/json` | **始终** — 硬编码 |

### 层 2：Route 级静态 Header

**文件:** `packages/llm/src/route/client.ts:193`

目前仅 Anthropic 设置 route 级 header：

| Header | Value | Provider |
|--------|-------|----------|
| `anthropic-version` | `2023-06-01` | **Anthropic** — `protocols/anthropic-messages.ts:764` |

### 层 3：Auth Header（按 Provider 不同）

**文件:** `packages/llm/src/route/auth.ts`

| Header | 格式 | Provider |
|--------|------|----------|
| `Authorization` | `Bearer <api_key>` | **OpenAI**、**OpenAI Compatible**（DeepSeek、Groq 等）、**XAI**、**GitHub Copilot**、**OpenRouter**、**Cloudflare Workers AI**、**Bedrock**（API key 模式） |
| `x-api-key` | `<api_key>` | **Anthropic** |
| `x-goog-api-key` | `<api_key>` | **Google Gemini** |
| `api-key` | `<api_key>` | **Azure** |
| `cf-aig-authorization` | `Bearer <token>` | **Cloudflare AI Gateway** |
| SigV4 签名 | `Authorization`、`x-amz-date`、`x-amz-security-token`、`x-amz-content-sha256` | **Amazon Bedrock**（默认） |

#### 认证链优先级（示例）

- **Anthropic**: `apiKey` 选项 → `ANTHROPIC_API_KEY` 环境变量 → 失败 → 作为 `x-api-key` 发送
- **OpenAI**: `apiKey` 选项 → `OPENAI_API_KEY` 环境变量 → 失败 → 作为 `Authorization: Bearer` 发送
- **Google**: `apiKey` 选项 → `GOOGLE_GENERATIVE_AI_API_KEY` 环境变量 → 作为 `x-goog-api-key` 发送
- **Azure**: `apiKey` 选项 → `AZURE_OPENAI_API_KEY` 环境变量 → 作为 `api-key` 发送（同时显式删除 `authorization` header）
- **Bedrock**: 若有 `apiKey` → `Authorization: Bearer`；否则 AWS SigV4 签名

### 层 4：用户自定义 Header

**文件:** `packages/llm/src/route/transport/http.ts:54-55`

```typescript
Headers.fromInput({
  ...input.headers?.({ request: input.request }),   // route 级静态
  ...input.request.http?.headers,                    // 用户每请求自定义
})
```

### 层 5：Route defaults.http.headers

**文件:** `packages/llm/src/route/client.ts:108-122`

Route 默认值可携带静态 header，通过 `mergeHttpOptions()` 合并。

## 各 Provider 最终 Header 汇总

| Provider | Auth Header(s) | 其他 Header |
|----------|---------------|---------------|
| **Anthropic** | `x-api-key: <key>` | `content-type: application/json`、`anthropic-version: 2023-06-01` |
| **OpenAI** | `Authorization: Bearer <key>` | `content-type: application/json` |
| **Google Gemini** | `x-goog-api-key: <key>` | `content-type: application/json` |
| **Amazon Bedrock** | SigV4: `Authorization`、`x-amz-date`、`x-amz-content-sha256`、`x-amz-security-token`（如有 session） | `content-type: application/json` |
| **Azure** | `api-key: <key>`（显式删除 `authorization`） | `content-type: application/json` |
| **Cloudflare AI Gateway** | `cf-aig-authorization: Bearer <token>` + 可选的 `Authorization: Bearer <upstream>` | `content-type: application/json` |
| **Cloudflare Workers AI** | `Authorization: Bearer <key>` | `content-type: application/json` |
| **OpenAI Compatible** | `Authorization: Bearer <key>` | `content-type: application/json` |
| **OpenRouter** | `Authorization: Bearer <key>` | `content-type: application/json` |
| **XAI** | `Authorization: Bearer <key>` | `content-type: application/json` |
| **GitHub Copilot** | `Authorization: Bearer <key>` | `content-type: application/json` |

## 应用层 Header（`request.ts`）

**文件:** `packages/opencode/src/session/llm/request.ts:168-184`

### opencode Provider 专用

| Header | Value |
|--------|-------|
| `x-opencode-project` | `<projectID>` |
| `x-opencode-session` | `<sessionID>` |
| `x-opencode-request` | `<requestID>` |
| `x-opencode-client` | client 标识 |
| `User-Agent` | `opencode/<version>` |

### 通用 Provider

| Header | Value |
|--------|-------|
| `x-session-affinity` | `<sessionID>` |
| `x-parent-session-id` | `<parentSessionID>`（仅子代理） |
| `User-Agent` | `opencode/<version>` |
