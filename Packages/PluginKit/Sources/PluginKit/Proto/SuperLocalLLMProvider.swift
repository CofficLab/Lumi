import Foundation
import AgentToolKit

// MARK: - Local Model Info

/// 本地模型信息（内核用，与具体插件解耦）
public struct LocalModelInfo: Identifiable, Sendable, Equatable {
    public let id: String
    public let displayName: String
    public let description: String
    public let size: String
    public let minRAM: Int
    public let expectedBytes: Int64
    public let supportsVision: Bool
    public let supportsTools: Bool
    public let priority: Int
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

/// 本地模型下载状态
public enum LocalDownloadStatus: Equatable, Sendable {
    case idle
    case downloading(fractionCompleted: Double)
    case completed
    case failed(String)
    case cancelling
}

// MARK: - Local LLM State

/// 本地推理状态
public enum LocalLLMState: Equatable, Sendable {
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
public protocol SuperLocalLLMProvider: SuperLLMProvider {

    /// 流式对话
    func streamChat(
        messages: [ChatMessage],
        model: String,
        tools: [SuperAgentTool]?,
        systemPrompt: String?,
        images: [ImageAttachment],
        onChunk: @Sendable (StreamChunk) async -> Void
    ) async throws -> ChatMessage

    /// 可用模型列表（动态）
    func getAvailableModels() async -> [LocalModelInfo]

    /// 已缓存模型 ID 集合
    func getCachedModels() async -> Set<String>

    /// 下载指定模型
    func downloadModel(id: String) async throws

    /// 加载指定模型到内存
    func loadModel(id: String) async throws

    /// 卸载当前模型
    func unloadModel() async

    /// 当前下载状态
    func getDownloadStatus() -> LocalDownloadStatus

    /// 当前推理状态
    func getModelState() async -> LocalLLMState

    /// 当前已加载到内存的模型 ID
    func getLoadedModelId() async -> String?

    /// 本地模型下载/缓存目录
    func getCacheDirectoryURL() -> URL

    /// 根据模型 ID 返回展示名
    func displayName(forModelId modelId: String) -> String?

    /// 非流式发送（可选实现）
    func sendMessage(
        messages: [ChatMessage],
        model: String,
        tools: [SuperAgentTool]?,
        systemPrompt: String?,
        images: [ImageAttachment]
    ) async throws -> ChatMessage
}

// MARK: - Defaults

extension SuperLocalLLMProvider {
    public func getLoadedModelId() async -> String? { nil }
    public func displayName(forModelId modelId: String) -> String? { nil }

    public func sendMessage(
        messages: [ChatMessage],
        model: String,
        tools: [SuperAgentTool]?,
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
