# Copilot Chat API 配置总览

## 一、API 端点与 URL

### 1.1 核心 CAPI（Copilot API）网关

所有主要 API 调用通过 `@vscode/copilot-api` 包（CAPIClient）路由，URL 从 Copilot Token 的 `endpoints` 字段动态解析。

| 端点类型 | 用途 | 来源 |
|----------|------|------|
| `api` | 主 API 入口 | `token.endpoints.api` |
| `proxy` | 代理服务 | `token.endpoints.proxy` |
| `telemetry` | 遥测服务 | `token.endpoints.telemetry` |
| `origin-tracker` | 来源追踪 | `token.endpoints['origin-tracker']` |

Debug 覆盖键：`ConfigKey.Shared.DebugOverrideCAPIUrl` / `ConfigKey.Shared.DebugOverrideProxyUrl`

### 1.2 Chat 请求类型（RequestType）

通过 `@vscode/copilot-api` 的 `RequestType` 路由到不同后端端点：

| RequestType | 对应 API |
|-------------|----------|
| `ChatCompletions` | `/chat/completions`（OpenAI 兼容） |
| `ChatMessages` | `/v1/messages`（Anthropic Messages API） |
| `ChatResponses` | `/responses` |
| `ProxyChatCompletions` | 代理聊天（instant apply、agentic search） |
| `CopilotToken` | 令牌端点 |
| `CopilotNLToken` | 匿名令牌端点 |
| `Models` | 模型列表 |
| `CopilotUserInfo` | 用户信息 |
| `CopilotSessions` | 会话管理 |

### 1.3 GitHub REST/GraphQL API

基础 URL：`https://api.github.com`（可通过 token 覆盖为企业 GHE 地址）

主要端点：
- `GET /user` — 当前用户
- `GET /repos/{owner}/{repo}` — 仓库信息
- `GET /graphql` — GraphQL API
- `GET /search/repositories` — 搜索仓库
- `GET /user/orgs` — 用户组织
- `POST /repos/{owner}/{repo}/pulls/{number}` — 操作 PR

### 1.4 BYOK（自带密钥）第三方提供商

| 提供商 | 基础 URL |
|--------|----------|
| OpenAI | `https://api.openai.com/v1` |
| Azure | 动态解析（`models.ai.azure.com` / `openai.azure.com`） |
| Anthropic | `api.anthropic.com` |
| Gemini | `generativelanguage.googleapis.com` |
| xAI | `https://api.x.ai/v1` |
| OpenRouter | `https://openrouter.ai/api/v1` |
| Ollama | `http://localhost:11434`（可配置） |

### 1.5 其他 URL

| 用途 | URL |
|------|-----|
| GitHub 状态 | `https://www.githubstatus.com/api/v2/status.json` |
| 反馈 | `https://aka.ms/microsoft/vscode-copilot-release` |
| SSH 代理日志 | `https://{endpoint}/agent-chat/v1/ssh/log` |
| CAPI 令牌 | `/copilot_internal/v2/token` |

### 1.6 端点定义枚举

```typescript
// src/platform/endpoint/common/endpointProvider.ts
export enum ModelSupportedEndpoint {
    ChatCompletions = '/chat/completions',
    Responses = '/responses',
    WebSocketResponses = 'ws:/responses',
    Messages = '/v1/messages'
}
```

---

## 二、认证机制

### 2.1 主认证流程

```
GitHub OAuth 登录 → 获取 GitHub Access Token → 交换为 Copilot HMAC Token
```

**GitHub OAuth Scope：**

| 级别 | Scope | 用途 |
|------|-------|------|
| 最小（any） | `user:email` | 基础 Copilot API 访问 |
| 完整（permissive） | `read:user`, `user:email`, `repo`, `workflow` | 完整仓库访问 |

**Token 交换流程（`copilotTokenManager.ts`）：**

```typescript
// 使用 GitHub token 获取 Copilot token
const options: FetchOptions = {
    callSite: 'copilot-token-github',
    headers: {
        Authorization: `token ${githubToken}`,
        'X-GitHub-Api-Version': '2025-04-01'
    },
    retryFallbacks: true,
    expectJSON: true,
};
const response = await this._capiClientService.makeRequest<Response>(
    options, { type: RequestType.CopilotToken }
);

// 匿名模式（无 GitHub 登录）
const options: FetchOptions = {
    callSite: 'copilot-token-device',
    headers: {
        'X-GitHub-Api-Version': '2025-04-01',
        'Editor-Device-Id': `${devDeviceId}`
    },
};
const response = await this._capiClientService.makeRequest<Response>(
    options, { type: RequestType.CopilotNLToken }
);
```

### 2.2 Copilot Token 结构

Token 格式：`fields:mac`，分号分隔的 `key=value` 对。

```typescript
// src/platform/authentication/common/copilotToken.ts
export interface Endpoints {
    api?: string;
    'origin-tracker'?: string;
    proxy?: string;
    telemetry?: string;
}
```

Token 包含字段：`token`, `expires_at`, `refresh_in`, `sku`, `endpoints`, `individual`, `organization_list`, `enterprise_list` 等。

Token 自动刷新：过期前 5 分钟缓冲期自动续期。

### 2.3 BYOK 认证模式

```typescript
// src/extension/byok/common/byokProvider.ts
export const enum BYOKAuthType {
    GlobalApiKey,        // 单一 API Key（OpenAI）
    PerModelDeployment,  // URL + API Key 每模型（Azure）
    None                 // 无认证（Ollama）
}
```

API Key 由用户输入，存储在 `IBYOKStorageService` 中。

### 2.4 环境变量（测试/自动化）

| 变量 | 用途 |
|------|------|
| `HMAC_SECRET` | CAPI 的 HMAC 密钥 |
| `VSCODE_COPILOT_INTEGRATION_ID` | CAPI 集成 ID |
| `GITHUB_PAT` | GitHub 个人访问令牌 |
| `GITHUB_OAUTH_TOKEN` | GitHub OAuth 令牌 |
| `VSCODE_COPILOT_CHAT_TOKEN` | 预生成的 Base64 ExtendedTokenInfo |
| `SIMULATION` | 设为 `1` 启用模拟模式 |
| `IS_SCENARIO_AUTOMATION` | 设为 `1` 启用自动化场景 |

---

## 三、请求 Headers

### 3.1 标准 CAPI 请求头

```typescript
// src/platform/networking/common/networking.ts
Authorization: Bearer <copilot-token>
X-Request-Id: <uuid>
OpenAI-Intent: <intent>
X-GitHub-Api-Version: 2025-05-01
X-Interaction-Type: <agent-interaction-type>
X-Agent-Task-Id: <request-id>
```

`agentInteractionType` 取值：`'conversation-subagent'` / `'conversation-background'` / intent 值。

### 3.2 A/B 实验头

```typescript
VScode-ABExpContext: <experiment-context>
X-Copilot-Client-Exp-Assignment-Context: <experiment-context>
```

### 3.3 编辑器版本头

```typescript
Editor-Version: <vscode-version>
Editor-Plugin-Version: <plugin-version>
X-VSCode-User-Agent-Library-Version: <library-version>
```

### 3.4 GitHub API 头

```typescript
Authorization: Bearer <github-token>
X-GitHub-Api-Version: 2025-04-01
User-Agent: <user-agent>
Accept: application/vnd.github+json
Content-Type: application/json          // GraphQL only
X-Client-Application: <application>
X-Client-Source: <plugin-info>
X-Client-Feature: <caller-info>
```

### 3.5 Anthropic Messages API 额外头

```typescript
anthropic-beta: interleaved-thinking-2025-05-14,context-management-2025-06-27,advanced-tool-use-2025-11-20
X-Model-Provider-Preference: <preference>
```

### 3.6 BYOK OpenAI 端点头

```typescript
// OpenAI / 通用
Authorization: Bearer <api-key>
Content-Type: application/json

// Azure
api-key: <api-key>
```

用户自定义 headers 受限，不可覆盖保留 headers（如 `host`, `authorization`, `cookie`, `user-agent` 等 20+ 个保留键）。

### 3.7 Proxy 4o 端点头

```typescript
Copilot-Edits-Session: <speculative-decoding-token>
```

---

## 四、关键配置键

所有配置键前缀：`github.copilot`

| 配置键 | 用途 | 类型 |
|--------|------|------|
| `chat.allowAnonymousAccess` | 匿名访问 | 用户设置 |
| `chat.anthropic.useMessagesApi` | 启用 Messages API | 实验性，默认 true |
| `teamInternal.modelProviderPreference` | 模型提供商偏好 | Team Internal |
| `teamInternal.responsesApiWebSocketEnabled` | WebSocket 响应传输 | 实验性 |
| `teamInternal.debugOverrideChatMaxTokenNum` | 覆盖最大 token | Debug |
| `shared.debugOverrideCAPIUrl` | 覆盖 CAPI URL | Debug |
| `shared.debugOverrideProxyUrl` | 覆盖代理 URL | Debug |
| `shared.authProvider` | 认证提供商（github / github-enterprise） | 用户设置 |
| `advanced.debugGitHubAuthFailWith` | 模拟认证失败 | Debug |
| `anthropic.thinkingBudget` | Anthropic 思考预算 | BYOK |
| `anthropic.contextEditingMode` | 上下文编辑模式 | 实验性 |
| `anthropic.webSearchToolEnabled` | Web 搜索工具 | 实验性 |
| `teamInternal.geminiFunctionCallingMode` | Gemini 函数调用模式 | 实验性 |

---

## 五、请求体参数

```typescript
// src/platform/networking/common/networking.ts → IEndpointBody
interface IEndpointBody {
    // OpenAI 标准
    model, messages, max_tokens, temperature, top_p, stream,
    tools, tool_choice, n, stop,

    // 推理
    reasoning: { effort, summary },
    thinking: { type, budget_tokens },
    thinking_budget,

    // Anthropic Messages API
    output_config: { effort },

    // Responses API
    input, truncation, include, store,
    text: { verbosity },
    previous_response_id,

    // 上下文管理
    context_management: { editing },

    // CAPI 专用
    copilot_references, copilot_confirmations, copilot_cache_control,

    // 其他
    intent, intent_threshold, snippy, prediction,
    stream_options, prompt_cache_key, top_logprobs,
}
```

---

## 六、模型元数据

### 6.1 来源

模型列表从 CAPI `/models` 端点获取，通过 `RequestType.Models`：

```typescript
const requestMetadata: RequestMetadata = { type: RequestType.Models, isModelLab: this._isModelLab };
```

### 6.2 模型结构

```typescript
interface IModelAPIResponse {
    id: string;                    // 模型 ID
    vendor: string;                // 提供商
    name: string;                  // 显示名
    version: string;
    model_picker_enabled: boolean; // 是否在模型选择器中显示
    is_chat_default: boolean;      // 是否默认聊天模型
    is_chat_fallback: boolean;     // 是否回退模型
    capabilities: {
        type: 'chat';
        family: string;            // 模型家族
        tokenizer: TokenizerType;
        limits: {
            max_prompt_tokens: number;
            max_output_tokens: number;
            max_context_window_tokens: number;
        };
        supports: {
            tool_calls, vision, streaming,
            prediction, thinking, adaptive_thinking,
            reasoning_effort: string[];
        };
    };
    supported_endpoints: ModelSupportedEndpoint[];  // 支持哪些 API 端点
    billing: {
        is_premium: boolean;
        multiplier: number;
        restricted_to: string[];
    };
    custom_model: { key_name, owner_name };  // BYOK 自定义模型
}
```

### 6.3 上下文窗口覆盖

通过实验 `copilotchat.contextWindows` 可覆盖模型的 token 限制：

```typescript
const expValue = this._expService.getTreatmentVariable<string>('copilotchat.contextWindows');
experimentalOverrides = JSON.parse(expValue ?? '{}');
```

---

## 七、网络请求基础设施

| 组件 | 说明 |
|------|------|
| `IFetcherService` | HTTP 请求抽象层 |
| `FetchOptions` | 请求配置：`callSite`, `headers`, `body`, `json`, `timeout`, `method`, `signal`, `retryFallbacks`, `expectJSON` |
| Fetcher 实现 | `electron-fetch`, `node-fetch`, `node-http`, `test-stub`, `helix-fetch` |
| 默认超时 | 30 秒 |
| `HeaderContributor` | 可插拔的额外 header 注入机制 |
| `SSEProcessor` | 流式 SSE 响应解析 |
| `ChatWebSocketManager` | WebSocket 传输（Responses API） |
| `ICAPIClientService` | CAPI 客户端，封装域名解析和 AB 实验上下文 |

---

## 八、核心文件索引

| 文件 | 内容 |
|------|------|
| `src/platform/networking/common/networking.ts` | 核心请求基础设施、标准 headers、IEndpointBody、30s 超时 |
| `src/platform/networking/common/fetcherService.ts` | Fetcher 接口、FetchOptions、Response |
| `src/platform/networking/common/openai.ts` | OpenAI/CAPI 消息类型、ChatCompletion |
| `src/platform/networking/common/anthropic.ts` | Anthropic Messages API 类型、上下文管理 |
| `src/platform/networking/common/fetch.ts` | RequestId、OptionalChatRequestParams |
| `src/platform/authentication/common/copilotToken.ts` | CopilotToken、TokenEnvelope、Endpoints、验证 |
| `src/platform/authentication/common/authentication.ts` | IAuthenticationService、GitHub 会话 scope |
| `src/platform/authentication/node/copilotTokenManager.ts` | Token 铸造（从 GitHub token/device ID） |
| `src/platform/authentication/vscode-node/copilotTokenManager.ts` | VS Code 特化 Token 管理、错误处理 |
| `src/platform/endpoint/common/capiClient.ts` | CAPI 客户端、AB 实验 headers |
| `src/platform/endpoint/node/capiClientImpl.ts` | CAPI 客户端实现、环境变量 |
| `src/platform/endpoint/node/chatEndpoint.ts` | Chat 端点、路由决策、请求体定制、额外 headers |
| `src/platform/endpoint/node/domainServiceImpl.ts` | 域名解析（从 token + debug 覆盖） |
| `src/platform/endpoint/common/domainService.ts` | IDomainService、FEEDBACK_URL |
| `src/platform/endpoint/common/endpointProvider.ts` | 模型类型、ModelSupportedEndpoint 枚举 |
| `src/platform/endpoint/node/modelMetadataFetcher.ts` | 模型发现、上下文窗口覆盖 |
| `src/platform/endpoint/node/messagesApi.ts` | Anthropic Messages API 请求/响应处理 |
| `src/platform/endpoint/node/responsesApi.ts` | Responses API 请求/响应处理 |
| `src/platform/configuration/common/configurationService.ts` | 配置键定义、ConfigKey |
| `src/platform/env/common/envService.ts` | 编辑器版本 headers |
| `src/platform/github/common/githubAPI.ts` | GitHub REST/GraphQL API |
| `src/platform/github/common/githubService.ts` | OctoKit 服务 |
| `src/extension/byok/common/byokProvider.ts` | BYOK 类型、isBYOKEnabled |
| `src/extension/byok/node/openAIEndpoint.ts` | BYOK OpenAI 端点、保留 headers 列表 |
| `src/extension/byok/vscode-node/openAIProvider.ts` | OpenAI 提供商 |
| `src/extension/byok/vscode-node/anthropicProvider.ts` | Anthropic 提供商 |
| `src/extension/byok/vscode-node/geminiNativeProvider.ts` | Gemini 提供商 |
| `src/platform/endpoint/node/proxy4oEndpoint.ts` | 代理端点（instant apply） |
| `src/platform/endpoint/node/proxyAgenticSearchEndpoint.ts` | 代理端点（agentic search） |
| `src/platform/networking/node/chatWebSocketManager.ts` | WebSocket 传输管理 |
