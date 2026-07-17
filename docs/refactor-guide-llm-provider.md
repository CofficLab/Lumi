# LLM Provider 基类重构指南

## 重构目标
删除 `OpenAICompatibleLumiProvider` 和 `AnthropicCompatibleProvider` 基类，让各供应商直接实现 `LumiLLMProvider` 协议，同时通过 `LumiLLMProviderSupport` 提供工具函数来复用代码。

## 已完成工作

### 1. 工具函数创建 ✅
- `LumiAPIKeyTools.swift` - API Key 管理（已存在）
- `LumiStreamingRequestSupport.swift` - 流式请求处理（已创建）
- `LumiTransportDetailsSupport.swift` - 传输详情工具（已创建）
- `ErrorDispositionResolver` - 错误处理（已存在）
- `LumiLLMProviderErrorSupport` - 错误消息生成（已存在）

### 2. OpenAI 兼容 Provider 迁移 ✅
- XybbzProvider
- FeifeimiaoProvider
- DeepSeekProvider
- MegaLLMProvider
- OpenRouterProvider
- LPgptProvider
- StepFunProvider
- FreeModelOpenAIBackend

### 3. Anthropic 兼容 Provider 迁移 ✅
- AnthropicProvider

### 4. 基类删除 ✅
- OpenAICompatibleLumiProvider.swift 已删除
- AnthropicCompatibleProvider.swift 已删除

### 5. Availability.swift 修复 ✅
- 删除了对基类的扩展方法

## 待完成工作

### 1. 修复 LumiStreamingRequestSupport.swift ✅
已移除 `providerID` 参数（不需要，可以直接从 request 或使用 Self.info.id）。

### 2. 剩余 Provider 迁移 ✅
以下 Provider 均已完成迁移（参考已完成的迁移模式）：

#### OpenAI 兼容:
- XiaomiAPIProvider (`Plugins/LLMProviderXiaomiPlugin/Sources/Providers/XiaomiAPIProvider.swift`)
- XiaomiProvider (`Plugins/LLMProviderXiaomiPlugin/Sources/Providers/XiaomiProvider.swift`)
- FlyMuxProvider (`Plugins/LLMProviderFlyMuxPlugin/Sources/FlyMuxProvider.swift`)

#### Anthropic 兼容:
- ZhipuProvider (`Plugins/LLMProviderZhipuPlugin/Sources/Providers/ZhipuProvider.swift`)
- AliyunProvider (`Plugins/LLMProviderAliyunPlugin/Sources/AliyunProvider.swift`)
- MiniMaxTokenPlanProvider (`Plugins/LLMProviderMiniMaxPlugin/Sources/MiniMaxTokenPlanProvider.swift`)
- FreeModelClaudeBackend (`Plugins/LLMProviderFreeModelPlugin/Sources/FreeModelClaudeBackend.swift`)

### 3. AvailabilityService 迁移 ✅
所有插件的 `AvailabilityService` 已从已删除的 `checkAvailabilityUsingChatPing(model:)`
基类方法迁移到 `LumiOpenAICompatibleAvailability.chatPing(...)` /
`LumiAnthropicCompatibleAvailability.chatPing(...)` 工具函数。注意这两个枚举是顶层
类型，不能写成 `provider.LumiOpenAICompatibleAvailability`（这是迁移时易犯的错误）。

### 4. 迁移模板

#### OpenAI 兼容 Provider 模板:
```swift
import Foundation
import HttpKit
import LLMKit
import LumiCoreKit
import LumiLLMProviderSupport

public final class YourProvider: LumiLLMProvider, @unchecked Sendable {
    public static let info = LumiLLMProviderInfo(
        // ... 保持原有的 info 配置
    )
    
    private let adapter: OpenAICompatibleProviderAdapter
    private let apiService: LLMAPIService
    
    public init(
        configuration: OpenAICompatibleProviderConfiguration? = nil,
        apiService: LLMAPIService = LLMAPIService()
    ) {
        let config = configuration ?? OpenAICompatibleProviderConfiguration(
            // ... 保持原有的配置
        )
        self.adapter = OpenAICompatibleProviderAdapter(configuration: config)
        self.apiService = apiService
    }
    
    // MARK: - LumiLLMProvider Protocol
    
    public func lumiResolveAPIKey() throws -> String {
        try LumiAPIKeyTools.resolve(
            storageKey: Self.info._apiKeyStorageKey,
            displayName: Self.info.displayName
        )
    }
    
    public func hasApiKey() -> Bool {
        LumiAPIKeyTools.has(storageKey: Self.info._apiKeyStorageKey)
    }
    
    public func getApiKey() -> String {
        LumiAPIKeyTools.get(storageKey: Self.info._apiKeyStorageKey)
    }
    
    public func setApiKey(_ apiKey: String) {
        LumiAPIKeyTools.set(apiKey, storageKey: Self.info._apiKeyStorageKey)
    }
    
    public func removeApiKey() {
        LumiAPIKeyTools.remove(storageKey: Self.info._apiKeyStorageKey)
    }
    
    public func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        try await sendStreaming(request) { _ in }
    }
    
    public func sendStreaming(
        _ request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage {
        try await LumiStreamingRequestSupport.sendOpenAICompatibleStreaming(
            request,
            providerID: Self.info.id,
            adapter: adapter,
            apiService: apiService,
            baseURLs: [adapter.configuration.baseURL] + adapter.configuration.fallbackBaseURLs,
            resolveAPIKey: lumiResolveAPIKey,
            buildRequest: { url, apiKey in
                adapter.buildRequest(url: url, apiKey: apiKey)
            },
            onChunk: onChunk
        )
    }
    
    public func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
        // 如果有自定义逻辑，保持不变
        // 否则使用: await LumiOpenAICompatibleAvailability.chatPing(...)
    }
    
    public func providerStatus() -> LumiLLMProviderStatus? {
        LumiLLMProviderStatusSupport.statusForRemoteAPIKeyProvider(provider: self)
    }
    
    public func retryDisposition(for error: Error, context: LumiLLMRetryContext) -> LumiLLMErrorDisposition {
        ErrorDispositionResolver.disposition(for: error, context: context)
    }
    
    public func errorRenderKind(for error: Error) -> String? {
        // 如果有自定义逻辑，保持不变
        nil
    }
    
    public func makeErrorMessage(
        conversationID: UUID,
        request: LumiLLMRequest,
        error: Error,
        disposition: LumiLLMErrorDisposition
    ) -> LumiChatMessage {
        LumiLLMProviderErrorSupport.makeErrorMessage(
            providerID: Self.info.id,
            conversationID: conversationID,
            request: request,
            error: error,
            disposition: disposition,
            renderKind: errorRenderKind(for: error)
        )
    }
}
```

#### Anthropic 兼容 Provider 模板:
```swift
// 与 OpenAI 兼容模板类似，只需更改:
// 1. adapter 类型为 AnthropicCompatibleProviderAdapter
// 2. sendStreaming 调用 sendAnthropicCompatibleStreaming
// 3. configuration 类型为 AnthropicCompatibleProviderConfiguration
```

### 5. 构建验证 ✅
运行以下命令验证（当前已通过）：
```bash
cd /Users/angel/Code/Coffic/Lumi
xcodebuild -scheme Lumi -configuration Debug -destination 'platform=macOS' build
```

### 4. 关键变更点

#### 类声明变更:
```swift
// 旧代码
public final class XybbzProvider: OpenAICompatibleLumiProvider, @unchecked Sendable {
    public override class var info: LumiLLMProviderInfo { ... }
    
    public init() {
        super.init(configuration: ...)
    }
}

// 新代码
public final class XybbzProvider: LumiLLMProvider, @unchecked Sendable {
    public static let info = LumiLLMProviderInfo(...)
    
    private let adapter: OpenAICompatibleProviderAdapter
    private let apiService: LLMAPIService
    
    public init(configuration: ...? = nil, apiService: LLMAPIService = LLMAPIService()) {
        self.adapter = OpenAICompatibleProviderAdapter(configuration: config)
        self.apiService = apiService
    }
}
```

#### 方法签名变更:
- `public override class var info` → `public static let info`
- `public override func xxx` → `public func xxx`
- 删除 `super.init()` 调用
- 添加 `adapter` 和 `apiService` 实例变量

## 成功标准
- ✅ OpenAICompatibleLumiProvider 和 AnthropicCompatibleProvider 两个基类被删除
- ✅ 所有 Provider 直接实现 LumiLLMProvider 协议
- ✅ 通用逻辑被提取为 LumiLLMProviderSupport 中的工具函数
- ✅ App 构建成功