# Copilot Chat API 端点选择机制

## 概述

Copilot Chat 支持三种不同的 API 端点，选择逻辑由 `ChatEndpoint`（`src/platform/endpoint/node/chatEndpoint.ts`）集中控制。最终由服务端返回的模型元数据决定。

## 三种端点对比

| 端点 | `RequestType` | 协议 | 请求体格式 | 响应处理 |
|------|--------------|------|-----------|----------|
| `/chat/completions` | `ChatCompletions` | OpenAI 兼容 | `createCapiRequestBody()` | SSE 流式解析 (`defaultChatResponseProcessor`) |
| `/v1/messages` | `ChatMessages` | Anthropic Messages API | `createMessagesRequestBody()` | `processResponseFromMessagesEndpoint()` |
| `/responses` | `ChatResponses` | Responses API | `createResponsesRequestBody()` | `processResponseFromChatEndpoint()` |

## 判别流程

```
模型元数据（CAPI /models 返回）
    │
    ▼
┌─ modelMetadata.urlOrRequestMetadata 有值？
│   ├── 是 → 直接使用该 URL/RequestMetadata
│   │        （BYOK 自定义端点、代理端点的场景）
│   └── 否 → 继续判断
│
├─ useResponsesApi？
│   ├── 是 → RequestType.ChatResponses → /responses
│   └── 否 → 继续判断
│       ↑
│       │ 条件：模型 supported_endpoints 包含 Responses
│
├─ useMessagesApi？
│   ├── 是 → RequestType.ChatMessages → /v1/messages
│   └── 否 → 继续判断
│       ↑
│       │ 条件：① chat.anthropic.useMessagesApi = true
│       │       ② 模型 supported_endpoints 包含 Messages
│
└─ 默认 → RequestType.ChatCompletions → /chat/completions
```

## 源码详解

### 1. 核心路由：`urlOrRequestMetadata`

```typescript
// src/platform/endpoint/node/chatEndpoint.ts:225-231
public get urlOrRequestMetadata(): string | RequestMetadata {
    return this.modelMetadata.urlOrRequestMetadata ??
        (this.useResponsesApi ? { type: RequestType.ChatResponses } :
            this.useMessagesApi ? { type: RequestType.ChatMessages } :
                { type: RequestType.ChatCompletions });
}
```

优先级：**模型自带 URL > Responses > Messages > Chat Completions（兜底）**

### 2. `useResponsesApi` — 纯服务端元数据驱动

```typescript
// src/platform/endpoint/node/chatEndpoint.ts:233-242
protected get useResponsesApi(): boolean {
    // 如果模型不支持 ChatCompletions 但支持 Responses → 强制启用
    if (this.modelMetadata.supported_endpoints
        && !this.modelMetadata.supported_endpoints.includes(ModelSupportedEndpoint.ChatCompletions)
        && this.modelMetadata.supported_endpoints.includes(ModelSupportedEndpoint.Responses)) {
        return true;
    }
    // 否则只要模型标记支持 Responses 就启用
    return !!this.modelMetadata.supported_endpoints?.includes(ModelSupportedEndpoint.Responses);
}
```

关键点：
- 没有客户端配置开关——完全由服务端返回的 `supported_endpoints` 决定
- 当模型 **不支持** ChatCompletions 但 **支持** Responses 时，强制走 Responses
- 当模型同上支持两者时，仍然优先 Responses

### 3. `useMessagesApi` — 需配置 + 元数据双重门控

```typescript
// src/platform/endpoint/node/chatEndpoint.ts:248-251
protected get useMessagesApi(): boolean {
    const enableMessagesApi = this._configurationService.getExperimentBasedConfig(
        ConfigKey.UseAnthropicMessagesApi, this._expService
    );
    return !!(enableMessagesApi
        && this.modelMetadata.supported_endpoints?.includes(ModelSupportedEndpoint.Messages));
}
```

双重条件：
1. 配置 `github.copilot.chat.anthropic.useMessagesApi` 为 `true`（实验性配置，默认 `true`）
2. 模型元数据 `supported_endpoints` 包含 `ModelSupportedEndpoint.Messages`

```typescript
// src/platform/configuration/common/configurationService.ts:881
export const UseAnthropicMessagesApi = defineSetting<boolean | undefined>(
    'chat.anthropic.useMessagesApi', ConfigType.ExperimentBased, true
);
```

### 4. `useWebSocketResponsesApi` — WebSocket 传输模式

```typescript
// src/platform/endpoint/node/chatEndpoint.ts:244-246
protected get useWebSocketResponsesApi(): boolean {
    return !!this.modelMetadata.supported_endpoints?.includes(ModelSupportedEndpoint.WebSocketResponses);
}
```

配合实验配置 `ConfigKey.TeamInternal.ResponsesApiWebSocketEnabled` 启用。

### 5. `apiType` — 用于遥测标识

```typescript
// src/platform/endpoint/node/chatEndpoint.ts:257-260
public get apiType(): string {
    return this.useResponsesApi ? 'responses' :
        this.useMessagesApi ? 'messages' : 'chatCompletions';
}
```

---

## 端点选择影响的三个环节

### 请求体构建（`createRequestBody`）

```typescript
// src/platform/endpoint/node/chatEndpoint.ts:291-311
createRequestBody(options: ICreateEndpointBodyOptions): IEndpointBody {
    if (this.useResponsesApi) {
        return createResponsesRequestBody(options, this.model, this);
    } else if (this.useMessagesApi) {
        return createMessagesRequestBody(options, this.model, this);
    } else {
        return createCapiRequestBody(options, this.model, this.getCompletionsCallback());
    }
}
```

### 响应解析（`processResponseFromChatEndpoint`）

```typescript
// src/platform/endpoint/node/chatEndpoint.ts:361-379
public async processResponseFromChatEndpoint(...): Promise<...> {
    if (this.useResponsesApi) {
        return processResponseFromChatEndpoint(...);
    } else if (this.useMessagesApi) {
        return processResponseFromMessagesEndpoint(...);
    } else if (!this._supportsStreaming) {
        return defaultNonStreamChatResponseProcessor(...);
    } else {
        return defaultChatResponseProcessor(...);
    }
}
```

### 额外 Headers（`getExtraHeaders`）

仅在 Messages API 模式下，当 `location` 为 Agent 或 MessagesProxy 时注入：

```typescript
// Anthropic beta features
anthropic-beta: interleaved-thinking-2025-05-14     // 非 adaptive_thinking 模型
anthropic-beta: context-management-2025-06-27       // 启用上下文编辑
anthropic-beta: advanced-tool-use-2025-11-20         // 启用工具搜索

// 模型提供商偏好
X-Model-Provider-Preference: <preference>
```

---

## 模型元数据来源

所有模型的 `supported_endpoints` 由 CAPI 的 `/models` 端点返回，客户端无法自行修改。

```typescript
// src/platform/endpoint/node/modelMetadataFetcher.ts:236-244
const requestMetadata: RequestMetadata = { type: RequestType.Models, isModelLab: this._isModelLab };
const response = await this._instantiationService.invokeFunction(getRequest, {
    endpointOrUrl: requestMetadata,
    secretKey: copilotToken,
    intent: 'model-access',
    requestId,
});
const data: IModelAPIResponse[] = (await response.json()).data;
```

客户端可用的覆盖：
- 通过实验 `copilotchat.contextWindows` 覆盖 token 限制
- 通过 `modelMetadata.urlOrRequestMetadata` 直接指定路由（BYOK、代理端点）

---

## 决策矩阵总结

| 场景 | `supported_endpoints` | 配置开关 | 结果 |
|------|----------------------|----------|------|
| BYOK 自定义 URL | `urlOrRequestMetadata` 有值 | — | 直接使用该 URL |
| Responses 优先 | 包含 `Responses` | — | `/responses` |
| Messages 配置启用 | 包含 `Messages` | `useMessagesApi=true` | `/v1/messages` |
| Messages 配置关闭 | 包含 `Messages` | `useMessagesApi=false` | `/chat/completions` |
| 仅 ChatCompletions | 仅 `ChatCompletions` | — | `/chat/completions` |
| 都无 | `[]` | — | `/chat/completions`（兜底） |

## 相关配置键

| 配置键 | 作用 | 默认值 |
|--------|------|--------|
| `github.copilot.chat.anthropic.useMessagesApi` | 启用 Messages API | `true`（实验性） |
| `github.copilot.teamInternal.modelProviderPreference` | 模型提供商偏好 | — |
| `github.copilot.teamInternal.responsesApiWebSocketEnabled` | WebSocket 传输 Responses | — |

## 核心文件

| 文件 | 职责 |
|------|------|
| `src/platform/endpoint/node/chatEndpoint.ts` | 端点选择核心逻辑、请求体构建、响应解析分发 |
| `src/platform/endpoint/common/endpointProvider.ts` | `ModelSupportedEndpoint` 枚举、模型类型定义 |
| `src/platform/endpoint/node/modelMetadataFetcher.ts` | 从 CAPI 获取模型元数据 |
| `src/platform/endpoint/node/messagesApi.ts` | Messages API 请求体/响应处理 |
| `src/platform/endpoint/node/responsesApi.ts` | Responses API 请求体/响应处理 |
| `src/platform/networking/common/networking.ts` | `createCapiRequestBody`、ChatCompletions 请求体 |
| `src/platform/configuration/common/configurationService.ts` | `UseAnthropicMessagesApi` 配置键定义 |
| `src/platform/endpoint/common/capiClient.ts` | CAPI 客户端、AB 实验上下文 |
