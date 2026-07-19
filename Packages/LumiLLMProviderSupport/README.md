# LumiLLMProviderSupport

LumiLLMProviderSupport 是 Lumi 项目中用于 LLM (Large Language Model) 供应商支持的 Swift 包。它提供了模型可用性检查、错误处理、重试决策、失败详情解析以及视觉消息支持等功能。

## 平台要求

- macOS 14.0+
- Swift 6.0+

## 依赖项

- [HttpKit](../HttpKit) - HTTP 客户端工具
- [LLMKit](../LLMKit) - LLM 核心功能
- [LLMProviderKit](../LLMProviderKit) - LLM 供应商适配器
- [LumiCoreKit](../LumiCoreKit) - Lumi 核心数据类型

## 功能模块

### 1. 模型可用性检查 (Availability Support)

提供通过 `chatPing` 方式检测 LLM 模型是否可用的功能。支持以下适配器：

- **OpenAI 兼容适配器** (`LumiOpenAICompatibleAvailability`)
- **Anthropic 兼容适配器** (`LumiAnthropicCompatibleAvailability`)

通过 `checkAvailabilityUsingChatPing(model:)` 方法可以快速验证模型连接状态。

### 2. 失败详情解析 (Failure Detail Resolver)

`LumiLLMFailureDetailResolver` 负责将错误转换为结构化的失败详情，包括：

- 错误摘要 (`summary`)
- HTTP 状态码 (`httpStatusCode`)
- 传输层详情 (`transportDetails`)
- 可用性展示文本 (`availabilityDisplayText`)

### 3. 错误处置决策 (Error Disposition Resolver)

`ErrorDispositionResolver` 根据错误类型和重试上下文决定：

- 错误是否可重试 (`isRetryable`)
- 重试延迟时间 (`retryDelaySeconds`)
- 相关元数据条目 (`metadataEntries`)

特殊处理：
- `CancellationError` 不可重试
- 实现 `LumiLLMErrorDispositionProviding` 协议的错误优先使用其自带决策
- 其他错误基于 HTTP 状态码和重试次数进行决策

### 4. HTTP 错误解析 (HTTP Error Parsing)

`LumiLLMHTTPErrorParsing` 提供从错误消息中提取 HTTP 状态码的能力，支持多种错误消息格式：

- `HTTP 错误 (429)`
- `HTTP error (401)`
- `HTTP 429`
- 纯数字状态码提取

### 5. 错误消息构建 (Error Message Support)

`LumiLLMProviderErrorSupport.makeErrorMessage` 用于构建标准化的错误聊天消息，包含：

- 供应商 ID 和模型名称
- 错误详情摘要
- 重试相关元数据
- 渲染类型信息

### 6. 传输层详情 (Transport Details)

`LumiLLMTransportDetails` 负责：

- 解析传输层错误消息
- 提取摘要和详细信息
- 生成结构化的传输元数据

### 7. 视觉消息支持 (Vision Message Support)

`LumiVisionMessageSupport` 提供视觉相关消息处理功能，包括：

- `LumiVisionContent` 数据类型
- `LumiVisionImage` 图像内容封装
- 视觉内容到 LLM 消息部分的转换

### 8. 国际化支持 (Localization)

`LumiLLMProviderSupportLocalization` 提供错误的本地化描述：

- 支持多语言错误描述
- 用户友好的错误消息展示
- 响应内容摘要提取

## 错误类型

### LumiLLMProviderSupportError

```swift
enum LumiLLMProviderSupportError: Error {
    case missingAPIKey(String)      // 缺少 API Key，携带供应商名称
    case streamingFailed(String)    // 流式请求失败，携带错误消息
    case allEndpointsFailed         // 所有供应商接口均失败
}
```

该错误类型实现了 `LocalizedError` 和 `LumiLLMErrorDispositionProviding` 协议。

## 使用示例

### 检查模型可用性

```swift
let provider = OpenAICompatibleLumiProvider(/* ... */)
let result = await provider.checkAvailabilityUsingChatPing(model: "gpt-4")

switch result {
case .available:
    print("模型可用")
case .unavailable(let detail):
    print("模型不可用: \(detail.summary)")
}
```

### 错误处置决策

```swift
let context = LumiLLMRetryContext(attempt: 1, maxAttempts: 3)
let disposition = ErrorDispositionResolver.disposition(for: error, context: context)

if disposition.isRetryable {
    try await Task.sleep(for: .seconds(disposition.retryDelaySeconds))
    // 重试请求
}
```

### 构建错误消息

```swift
let errorMessage = LumiLLMProviderErrorSupport.makeErrorMessage(
    providerID: "openai",
    conversationID: conversation.id,
    request: llmRequest,
    error: error,
    disposition: disposition,
    renderKind: "text"
)
```

## 项目结构

```
LumiLLMProviderSupport/
├── Package.swift
├── Sources/
│   ├── Models/
│   │   ├── Errors.swift                # 核心错误类型
│   │   ├── TransportDetails.swift      # 传输层数据模型
│   │   └── VisionMessages.swift        # 视觉消息数据类型
│   ├── Services/
│   │   ├── FailureDetailResolver.swift # 失败详情解析服务
│   │   ├── RetryResolver.swift         # 错误处置决策服务
│   │   └── Availability.swift          # 模型可用性检查服务
│   └── Utilities/
│       └── Localization.swift          # 国际化/本地化工具
├── Tests/
│   ├── LumiLLMProviderSupportErrorTests.swift
│   ├── LumiLLMFailureDetailResolverTests.swift
│   ├── LumiLLMTransportDetailsTests.swift
│   └── LumiVisionMessageSupportTests.swift
└── Resources/
    └── Localizable.xcstrings           # 本地化资源
```

## 测试

运行测试：

```bash
swift test --filter LumiLLMProviderSupportTests
```

## 许可证

本包是 Lumi 项目的一部分，遵循 Lumi 项目的许可证条款。
