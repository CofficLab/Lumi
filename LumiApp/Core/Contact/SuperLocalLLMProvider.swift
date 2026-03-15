import Foundation

// MARK: - Local Model Info

/// 本地模型信息（内核用，与具体插件解耦）
///
/// 用于设置页展示可用模型列表、大小、内存要求、描述等。
/// 插件可选的 supportsVision、supportsTools、priority 用于排序与按能力过滤。
public struct LocalModelInfo: Identifiable, Sendable, Equatable {
    public let id: String
    public let displayName: String
    /// 模型描述（可选，用于设置页展示）
    public let description: String
    public let size: String
    public let minRAM: Int
    public let expectedBytes: Int64
    /// 是否支持视觉输入（VLM），默认 false
    public let supportsVision: Bool
    /// 是否支持工具调用，默认 true
    public let supportsTools: Bool
    /// 推荐优先级（越小越靠前），默认 0
    public let priority: Int
    /// 系列名称（可选），用于设置页按系列分组展示，如「Qwen 系列」「Mistral 系列」
    public let series: String?

    public init(
        id: String,
        displayName: String,
        description: String = "",
        size: String,
        minRAM: Int,
        expectedBytes: Int64,
        supportsVision: Bool = false,
        supportsTools: Bool = true,
        priority: Int = 0,
        series: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.size = size
        self.minRAM = minRAM
        self.expectedBytes = expectedBytes
        self.supportsVision = supportsVision
        self.supportsTools = supportsTools
        self.priority = priority
        self.series = series
    }
}

// MARK: - Local Download Status

/// 本地模型下载状态（内核用）
enum LocalDownloadStatus: Equatable, Sendable {
    case idle
    case downloading(fractionCompleted: Double)
    case completed
    case failed(String)
    case cancelling
}

// MARK: - Local LLM State

/// 本地推理状态（内核用）
enum LocalLLMState: Equatable, Sendable {
    case idle
    case loading
    case ready
    case generating
    case error(String)
}

// MARK: - Super Local LLM Provider

/// 本地 LLM 供应商协议
///
/// 继承 SuperLLMProvider，使本地供应商与远程供应商使用同一套注册与列表。
/// 内核仅依赖本协议，不依赖具体插件（如 MLX）；删除插件不影响内核。
protocol SuperLocalLLMProvider: SuperLLMProvider {

    /// 流式对话：将 Core 消息转为本地格式，生成 StreamChunk 流并回调，最后返回完整 ChatMessage
    func streamChat(
        messages: [ChatMessage],
        model: String,
        tools: [AgentTool]?,
        systemPrompt: String?,
        images: [ImageAttachment],
        onChunk: @Sendable (StreamChunk) async -> Void
    ) async throws -> ChatMessage

    /// 可用模型列表（动态，用于设置页“本地模型”区块）
    func getAvailableModels() async -> [LocalModelInfo]

    /// 已缓存模型 ID 集合
    func getCachedModels() async -> Set<String>

    /// 下载指定模型
    func downloadModel(id: String) async throws

    /// 加载指定模型到内存
    func loadModel(id: String) async throws

    /// 卸载当前模型
    func unloadModel() async

    /// 当前下载状态（用于设置页进度展示）
    func getDownloadStatus() -> LocalDownloadStatus

    /// 当前推理状态（可选，用于“已加载”等展示）
    func getModelState() async -> LocalLLMState

    /// 当前已加载到内存的模型 ID（nil 表示未加载），用于设置页加载/卸载按钮状态
    func getLoadedModelId() async -> String?

    /// 本地模型下载/缓存目录（用于设置页“打开下载目录”）
    func getCacheDirectoryURL() -> URL

    /// 非流式发送（可选实现；默认通过 streamChat 消费流后返回最终消息）
    func sendMessage(
        messages: [ChatMessage],
        model: String,
        tools: [AgentTool]?,
        systemPrompt: String?,
        images: [ImageAttachment]
    ) async throws -> ChatMessage
}

// MARK: - Defaults

extension SuperLocalLLMProvider {
    /// 默认：无模型加载
    func getLoadedModelId() async -> String? { nil }

    /// 默认实现：消费 streamChat 流并返回最终消息
    func sendMessage(
        messages: [ChatMessage],
        model: String,
        tools: [AgentTool]?,
        systemPrompt: String?,
        images: [ImageAttachment]
    ) async throws -> ChatMessage {
        try await streamChat(
            messages: messages,
            model: model,
            tools: tools,
            systemPrompt: systemPrompt,
            images: images,
            onChunk: { _ in }
        )
    }
}
