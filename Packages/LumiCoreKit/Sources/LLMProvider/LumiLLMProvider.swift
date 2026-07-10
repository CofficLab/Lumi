import Foundation

/// LLM 模型可用性检测结果
public enum LumiModelAvailabilityResult: Sendable, Equatable {
    /// 模型可用
    case available
    /// 模型不可用，附带结构化失败信息
    case unavailable(LumiLLMFailureDetail)
}

/// 模型能力声明
public struct LumiModelCapabilities: Sendable, Equatable {
    /// 是否支持视觉输入（图片）
    public let supportsVision: Bool
    /// 是否支持工具调用
    public let supportsTools: Bool
    /// 是否支持文本转语音（TTS）
    public let supportsTTS: Bool

    public init(
        supportsVision: Bool,
        supportsTools: Bool,
        supportsTTS: Bool = false
    ) {
        self.supportsVision = supportsVision
        self.supportsTools = supportsTools
        self.supportsTTS = supportsTTS
    }
}

public struct LumiLLMProviderInfo: Identifiable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let description: String
    public let defaultModel: String
    public let availableModels: [String]
    public let isLocal: Bool
    public let contextWindowSizes: [String: Int]
    /// 各模型的能力声明（key 为模型 ID）
    public let modelCapabilities: [String: LumiModelCapabilities]
    /// 各模型的展示名称（key 为模型 ID）；未命中时 UI 回退到原始 ID
    public let modelDisplayNames: [String: String]
    /// 供应商官网/控制台页面（用于设置页跳转）
    public let websiteURL: URL
    /// API Key 在 Keychain 中的存储键；本地供应商为 nil
    ///
    /// **仅供 Provider 内部使用（internal）**：外部代码（含设置页、可用性检测、迁移脚本）
    /// **禁止**直接读取此字段。API Key 的访问应通过 `LumiLLMProvider` 协议方法
    /// (`hasApiKey` / `getApiKey` / `setApiKey` / `removeApiKey`)，
    /// 由具体供应商决定存储策略。
    ///
    /// 之所以保留在 info 上，是因为：基类 `AnthropicCompatibleLumiProvider` /
    /// `OpenAICompatibleLumiProvider` 需要一个权威存储键来提供默认实现；
    /// 任何子类如果想用不同的存储策略，仍然可以 override 这几个协议方法。
    internal let apiKeyStorageKey: String?

    /// Provider 内部（含跨包基类）获取 API Key 存储键的唯一公开入口。
    /// 外部代码（设置页、可用性检测等）禁止直接读取，应通过协议方法访问。
    public var _apiKeyStorageKey: String? { apiKeyStorageKey }

    public init(
        id: String,
        displayName: String,
        description: String = "",
        defaultModel: String,
        availableModels: [String],
        isLocal: Bool = false,
        contextWindowSizes: [String: Int] = [:],
        modelCapabilities: [String: LumiModelCapabilities] = [:],
        modelDisplayNames: [String: String] = [:],
        websiteURL: URL,
        apiKeyStorageKey: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.defaultModel = defaultModel
        self.availableModels = availableModels
        self.isLocal = isLocal
        self.contextWindowSizes = contextWindowSizes
        self.modelCapabilities = modelCapabilities
        self.modelDisplayNames = modelDisplayNames
        self.websiteURL = websiteURL
        // 本地供应商无需 API Key；远程供应商使用传入值或按 id 生成默认键
        if isLocal {
            self.apiKeyStorageKey = nil
        } else {
            self.apiKeyStorageKey = apiKeyStorageKey ?? "DevAssistant_ApiKey_\(id)"
        }
    }
}

public struct LumiLLMRequest: Sendable {
    public let messages: [LumiChatMessage]
    public let model: String
    public let tools: [any LumiAgentTool]
    public let imageAttachments: [LumiImageAttachment]

    public init(
        messages: [LumiChatMessage],
        model: String,
        tools: [any LumiAgentTool] = [],
        imageAttachments: [LumiImageAttachment] = []
    ) {
        self.messages = messages
        self.model = model
        self.tools = tools
        self.imageAttachments = imageAttachments
    }
}

public protocol LumiLLMProvider: Sendable {
    static var info: LumiLLMProviderInfo { get }

    /// 解析 API Key；由具体供应商实现存储策略
    func lumiResolveAPIKey() throws -> String

    /// 是否已配置 API Key。本地供应商恒为 `true`。
    /// 默认实现基于 `lumiResolveAPIKey()`。
    func hasApiKey() -> Bool

    /// 读取当前已配置的 API Key；未配置时返回空字符串。
    /// 默认实现基于 `lumiResolveAPIKey()`。
    func getApiKey() -> String

    /// 写入 API Key。具体存储策略由供应商自行决定（Keychain / 配置文件 / 内存等）。
    /// 协议层不规定存储方式；外部只能通过本方法写入。
    func setApiKey(_ apiKey: String)

    /// 删除 API Key。
    func removeApiKey()

    func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage

    func sendStreaming(
        _ request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage

    /// 检查指定模型是否可用。
    /// - Parameter model: 模型名称
    /// - Returns: 模型可用性检测结果
    func checkAvailability(model: String) async -> LumiModelAvailabilityResult

    /// 供应商为模型选择器等 UI 提供的当前状态说明（如缺少 API Key、套餐过期）。
    /// 每个供应商都必须实现；无问题时返回 `nil`。
    func providerStatus() -> LumiLLMProviderStatus?

    /// 供应商对单次失败的重试决策；子类可 override。
    func retryDisposition(for error: Error, context: LumiLLMRetryContext) -> LumiLLMErrorDisposition

    /// 将异常映射为错误消息的 `renderKind`；无自定义渲染时返回 `nil`。
    func errorRenderKind(for error: Error) -> String?

    /// 由调用方在重试耗尽或不可重试时，将 throw 的错误转为可展示的错误消息。
    func makeErrorMessage(
        conversationID: UUID,
        request: LumiLLMRequest,
        error: Error,
        disposition: LumiLLMErrorDisposition
    ) -> LumiChatMessage
}

public extension LumiLLMProvider {
    /// 默认实现：本地供应商恒为 `true`；远程供应商基于 `info.apiKeyStorageKey` 读 Keychain。
    /// 子类若要使用 Keychain 之外的存储策略，可 override。
    func hasApiKey() -> Bool {
        if Self.info.isLocal { return true }
        guard let storageKey = Self.info.apiKeyStorageKey else { return true }
        let key = LumiAPIKeyStore.shared.loadMigratingLegacyUserDefaults(forKey: storageKey) ?? ""
        return !key.isEmpty
    }

    /// 默认实现：本地供应商返回空串；远程供应商基于 `info.apiKeyStorageKey` 读 Keychain。
    func getApiKey() -> String {
        if Self.info.isLocal { return "" }
        guard let storageKey = Self.info.apiKeyStorageKey else { return "" }
        return LumiAPIKeyStore.shared.loadMigratingLegacyUserDefaults(forKey: storageKey) ?? ""
    }

    /// 默认实现：基于 `info.apiKeyStorageKey` 写 Keychain。
    /// 子类若要使用其他存储策略（如加密文件、外部 Vault），可 override。
    func setApiKey(_ apiKey: String) {
        guard let storageKey = Self.info.apiKeyStorageKey else { return }
        LumiAPIKeyStore.shared.set(apiKey, forKey: storageKey)
    }

    /// 默认实现：基于 `info.apiKeyStorageKey` 从 Keychain 删除。
    func removeApiKey() {
        guard let storageKey = Self.info.apiKeyStorageKey else { return }
        LumiAPIKeyStore.shared.remove(forKey: storageKey)
    }

    /// 默认实现：本地供应商返回空串；远程供应商读 Keychain，缺失时抛 `missingAPIKey`。
    /// 大多数 Provider 不需要 override 此方法。
    func lumiResolveAPIKey() throws -> String {
        if Self.info.isLocal { return "" }
        guard let storageKey = Self.info.apiKeyStorageKey else {
            throw LumiLLMProviderSupportError.missingAPIKey(Self.info.displayName)
        }
        let key = LumiAPIKeyStore.shared.loadMigratingLegacyUserDefaults(forKey: storageKey) ?? ""
        if key.isEmpty {
            throw LumiLLMProviderSupportError.missingAPIKey(Self.info.displayName)
        }
        return key
    }

    func retryDisposition(for error: Error, context: LumiLLMRetryContext) -> LumiLLMErrorDisposition {
        if let providing = error as? LumiLLMErrorDispositionProviding {
            return providing.llmErrorDisposition
        }
        return .nonRetryable
    }

    func errorRenderKind(for error: Error) -> String? {
        nil
    }

    // MARK: - 静态便捷方法（供 plugin 内部 View 在没有 provider 实例时使用）

    /// 静态版本：等价于 `Self().getApiKey()`，但避免每次新建实例。
    /// 内部 View 经常以静态方式访问（如 `AliyunProvider.getApiKey()`），提供此默认实现
    /// 让子类不必重复样板代码。
    static func getApiKey() -> String {
        if Self.info.isLocal { return "" }
        guard let storageKey = Self.info.apiKeyStorageKey else { return "" }
        return LumiAPIKeyStore.shared.loadMigratingLegacyUserDefaults(forKey: storageKey) ?? ""
    }

    /// 静态版本：等价于 `Self().setApiKey(_:)`，但避免每次新建实例。
    static func setApiKey(_ apiKey: String) {
        guard let storageKey = Self.info.apiKeyStorageKey else { return }
        LumiAPIKeyStore.shared.set(apiKey, forKey: storageKey)
    }

    func makeErrorMessage(
        conversationID: UUID,
        request: LumiLLMRequest,
        error: Error,
        disposition: LumiLLMErrorDisposition
    ) -> LumiChatMessage {
        let metadata = disposition.metadataEntries
        let detail = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        return LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "",
            providerID: Self.info.id,
            modelName: request.model,
            isError: true,
            rawErrorDetail: detail,
            metadata: metadata
        )
    }

    func sendStreaming(
        _ request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage {
        let message = try await send(request)
        if !message.content.isEmpty {
            await onChunk(LumiStreamChunk(content: message.content, eventTitle: "生成中"))
        }
        await onChunk(LumiStreamChunk(isDone: true, eventTitle: "结束"))
        return message
    }
}