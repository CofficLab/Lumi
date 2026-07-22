import AgentToolKit
import Combine
import Foundation
import HttpKit
import LLMKit
import LumiKernel
import LumiKernel
import LumiKernel
import os
import SuperLogKit

/// MLX 本地模型 Provider
///
/// 将 MLX 本地模型集成到 LLM 供应商体系中。
/// 实现 SuperLLMProvider 协议，使得本地模型可以像
/// Anthropic、OpenAI 等云服务一样被调用。
///
/// 特性：
/// - 本地运行，无需 API Key
/// - 支持流式对话
/// - 支持工具调用
/// - 支持图片输入（VLM 模型）
@available(macOS 14.0, *)
public final class MLXProvider: SuperLLMProvider, SuperLocalLLMProvider, SuperLog, @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "llm.mlx")
    nonisolated public static let emoji = "💻"
    public nonisolated static let verbose: Bool = true
    // MARK: - Provider Info

    /// 供应商唯一标识符
    public static var id: String { "mlx" }

    /// 显示名称
    public static var displayName: String { "MLX" }

    /// 简写名称
    public static var shortName: String { "MLX" }

    /// 图标名称（SF Symbols）
    public static var iconName: String { "cpu" }

    /// 供应商描述
    public static var description: String { "本地运行的模型（无需网络）" }

    /// API Key 存储键名 - 本地模型不需要 API Key
    public static let apiKeyStorageKey: String = ""

    public func lumiResolveAPIKey() throws -> String {
        let key = APIKeyStore.shared.loadMigratingLegacyUserDefaults(forKey: Self.apiKeyStorageKey) ?? ""
        if key.isEmpty {
            throw LumiLLMProviderSupportError.missingAPIKey(Self.info.displayName)
        }
        return key
    }

    /// 模型选择存储键名

    /// 默认模型
    public static var defaultModel: String { "mlx-community/Qwen3.5-9B-4bit" }

    /// 可用模型列表（支持工具调用的推荐模型，按优先级排序）
    public static var availableModels: [String] {
        MLXModels.toolModels
            .sorted { $0.priority < $1.priority }
            .map(\.id)
    }

    // MARK: - SuperLLMProvider 桩实现（本地供应商不走 HTTP）

    public var baseURL: String { "" }

    public func buildRequest(url: URL) -> URLRequest {
        URLRequest(url: url)
    }

    public func buildRequestBody(messages: [ChatMessage], model: String, tools: [SuperAgentTool]?, systemPrompt: String) throws -> [String: Any] {
        throw MLXError.notSupported("本地模型请使用流式或本地 sendMessage")
    }

    public func parseResponse(data: Data) throws -> (content: String, toolCalls: [AgentToolKit.ToolCall]?) {
        throw MLXError.notSupported("本地模型请使用流式或本地 sendMessage")
    }

    public func parseStreamChunk(data: Data) throws -> StreamChunk? {
        nil
    }

    public func buildStreamingRequestBody(messages: [ChatMessage], model: String, tools: [SuperAgentTool]?, systemPrompt: String) throws -> [String: Any] {
        throw MLXError.notSupported("本地模型请使用流式或本地 sendMessage")
    }

    /// 获取下载管理器实例
    ///
    /// 使用单例确保下载任务独立于视图生命周期，
    /// 即使视图关闭也能在后台继续下载，重新打开时恢复进度。
    public static var downloadManager: MLXDownloadManager {
        .shared
    }

    /// 仅在 MainActor 上访问，用于满足 MLXInferenceService 的 @MainActor 隔离。
    private nonisolated(unsafe) var inferenceService: MLXInferenceService?
    private var modelManager: MLXModelManager?
    private nonisolated(unsafe) var currentModelId: String?

    // MARK: - Initialization

    public init() {
        if Self.verbose {
            if Self.verbose {
                            Self.logger.info("\(self.t) MLX Provider 已初始化")
            }
        }
    }

    deinit {
        shutdown()
    }

    private func ensureServices() async {
        await MainActor.run {
            if self.inferenceService == nil {
                self.inferenceService = MLXInferenceService()
                self.modelManager = self.modelManager ?? MLXModelManager()
            }
        }
    }

    // MARK: - Public Methods

    /// 根据模型 ID 返回展示名（用于输入栏等）
    public func displayName(forModelId modelId: String) -> String? {
        MLXModels.model(id: modelId)?.displayName
    }

    /// 检查模型是否已下载
    public func isModelDownloaded(id: String) -> Bool {
        let cacheDir = cacheDirectory(for: id)
        return FileManager.default.fileExists(atPath: cacheDir.path) && containsValidSafetensorsFiles(cacheDir)
    }

    /// 下载模型
    public func downloadModel(id: String) async throws {
        await ensureServices()

        let manager = Self.downloadManager

        if isModelDownloaded(id: id) {
            if Self.verbose {
                if Self.verbose {
                                    Self.logger.info("\(self.t) 模型已下载：\(id)")
                }
            }
            return
        }

        await manager.download(modelId: id)

        if manager.status == .completed {
            if Self.verbose {
                if Self.verbose {
                                    Self.logger.info("\(self.t) 模型下载完成：\(id)")
                }
            }
        } else if case .failed(let error) = manager.status {
            throw MLXError.downloadFailed(error)
        }
    }

    /// 取消下载
    public func cancelDownload() {
        Task { @MainActor in
            Self.downloadManager.cancel()
        }
    }

    /// 获取下载进度
    public func getDownloadProgress() -> DownloadProgress {
        Task { @MainActor in
            Self.downloadManager.progress
        }
        // 同步返回最后一次快照值（避免阻塞）
        return DownloadProgress()
    }

    /// 加载模型
    public func loadModel(id: String) async throws {
        await ensureServices()

        guard isModelDownloaded(id: id) else {
            throw MLXError.modelNotDownloaded
        }

        if currentModelId != nil {
            await unloadModel()
        }

        let service = await MainActor.run { self.inferenceService }
        guard let service else {
            throw MLXError.inferenceNotReady
        }

        try await service.loadModel(id: id)
        currentModelId = id

        if Self.verbose {
            if Self.verbose {
                            Self.logger.info("\(self.t) 模型已加载：\(id)")
            }
        }
    }

    /// 卸载模型
    public func unloadModel() async {
        await MainActor.run { self.inferenceService?.unloadModel() }
        currentModelId = nil
        if Self.verbose {
            if Self.verbose {
                            Self.logger.info("\(self.t) 模型已卸载")
            }
        }
    }

    /// 获取当前加载的模型 ID
    public func getCurrentModelId() -> String? {
        currentModelId
    }

    /// 检查模型是否已加载
    public func isModelLoaded(id: String) async -> Bool {
        let state = await MainActor.run { self.inferenceService?.state ?? .idle }
        return currentModelId == id && state == .ready
    }

    // MARK: - SuperLocalLLMProvider

    public func streamChat(
        messages: [ChatMessage],
        model: String,
        tools: [SuperAgentTool]?,
        systemPrompt: String?,
        images: [ImageAttachment],
        onChunk: @Sendable (StreamChunk) async -> Void
    ) async throws -> ChatMessage {
        await ensureServices()
        let mxMessages = Self.chatMessagesToMLX(messages, systemPrompt: systemPrompt, lastUserImages: images)
        let toolsFormatted = Self.agentToolsToMLX(tools)
        let stream = await self.mlStreamChat(messages: mxMessages, tools: toolsFormatted, images: images)
        var accumulatedContent: [String] = []
        var accumulatedToolCalls: [ToolCall] = []
        var streamError: String?
        for await chunk in stream {
            switch chunk {
            case .text(let s):
                accumulatedContent.append(s)
                await onChunk(StreamChunk(content: s, eventType: .textDelta, rawStreamPayload: s))
            case .toolCall(let tc):
                let coreTc = ToolCall(id: tc.id, name: tc.name, arguments: tc.arguments)
                accumulatedToolCalls.append(coreTc)
                await onChunk(StreamChunk(toolCalls: [coreTc], rawStreamPayload: tc.arguments))
            case .error(let err):
                streamError = err
                await onChunk(StreamChunk(error: err, rawStreamPayload: err))
            }
        }
        if let err = streamError {
            throw NSError(domain: "MLXProvider", code: 500, userInfo: [NSLocalizedDescriptionKey: err])
        }
        let content = accumulatedContent.joined()
        return ChatMessage(
            role: .assistant, conversationId: UUID(),
            content: content,
            toolCalls: accumulatedToolCalls.isEmpty ? nil : accumulatedToolCalls,
            providerId: Self.id,
            modelName: model
        )
    }

    public func getAvailableModels() async -> [LocalModelInfo] {
        modelManager?.availableModels() ?? MLXModels.availableModels(for: nil)
    }

    public func getCachedModels() async -> Set<String> {
        await ensureServices()
        return modelManager?.cachedModelIds ?? []
    }

    public func getDownloadStatus() -> LocalDownloadStatus {
        let status = Self.downloadManager.status
        let progress = Self.downloadManager.progress
        switch status {
        case .idle: return .idle
        case .downloading: return .downloading(fractionCompleted: progress.fractionCompleted)
        case .completed: return .completed
        case .failed(let s): return .failed(s)
        case .cancelling: return .cancelling
        case .paused: return .downloading(fractionCompleted: progress.fractionCompleted)
        }
    }

    public func getModelState() async -> LocalLLMState {
        let state = await MainActor.run { self.inferenceService?.state ?? .idle }
        switch state {
        case .idle: return .idle
        case .loading: return .loading
        case .ready: return .ready
        case .generating: return .generating
        case .error(let s): return .error(s)
        }
    }

    public func getLoadedModelId() async -> String? {
        await MainActor.run { self.currentModelId }
    }

    /// 内部流式对话（返回 MLX 的 GenerationChunk 流）
    private func mlStreamChat(
        messages: [MLXChatMessage],
        tools: [[String: Sendable]]?,
        images: [ImageAttachment]
    ) async -> AsyncStream<GenerationChunk> {
        let (state, service) = await MainActor.run { (self.inferenceService?.state, self.inferenceService) }
        guard state == .ready, let service else {
            return AsyncStream { continuation in
                continuation.yield(.error("模型未就绪"))
                continuation.finish()
            }
        }
        return await MainActor.run {
            service.chat(messages: messages, tools: tools, images: images)
        }
    }

    private static func chatMessagesToMLX(_ messages: [ChatMessage], systemPrompt: String?, lastUserImages: [ImageAttachment]) -> [MLXChatMessage] {
        var list: [MLXChatMessage] = []
        if let prompt = systemPrompt, !prompt.isEmpty {
            list.append(MLXChatMessage(role: .system, content: prompt))
        }
        let lastUserIndex = messages.lastIndex(where: { $0.role == .user })
        for (idx, m) in messages.enumerated() {
            switch m.role {
            case .system:
                list.append(MLXChatMessage(role: .system, content: m.content))
            case .user:
                let images = (idx == lastUserIndex) ? (m.images.isEmpty ? lastUserImages : m.images) : []
                list.append(MLXChatMessage(role: .user, content: m.content, images: images))
            case .assistant:
                list.append(MLXChatMessage(role: .assistant, content: m.content))
            case .tool, .status, .error, .unknown:
                break
            }
        }
        return list
    }

    private static func agentToolsToMLX(_ tools: [SuperAgentTool]?) -> [[String: Sendable]]? {
        guard let tools, !tools.isEmpty else { return nil }
        return tools.map { t in
            let paramsJson = (try? JSONSerialization.data(withJSONObject: t.inputSchema(for: .english))).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
            return ["name": t.name as Sendable, "description": t.description(for: .english) as Sendable, "parameters": paramsJson as Sendable] as [String: Sendable]
        }
    }

    /// 停止生成
    public func stopGeneration() {
        Task { @MainActor in self.inferenceService?.stopGeneration() }
    }

    public func shutdown() {
        modelManager?.stopMonitoring()

        let inferenceService = inferenceService
        Task { @MainActor in
            inferenceService?.unloadModel()
        }

        self.inferenceService = nil
        self.modelManager = nil
        self.currentModelId = nil
    }

    /// 获取生成速度
    public func getTokensPerSecond() async -> Double {
        await MainActor.run { self.inferenceService?.tokensPerSecond ?? 0 }
    }

    /// 删除模型
    public func deleteModel(id: String) throws {
        try modelManager?.deleteModel(id: id)
        if Self.verbose {
            if Self.verbose {
                            Self.logger.info("\(self.t) 模型已删除：\(id)")
            }
        }
    }

    /// 获取可用模型列表（根据 RAM 过滤，供内部/扩展使用）
    public func getAvailableModels() -> [LocalModelInfo] {
        modelManager?.availableModels() ?? MLXModels.availableModels(for: nil)
    }

    /// 获取已缓存的模型列表
    public func getCachedModels() -> Set<String> {
        modelManager?.cachedModelIds ?? []
    }

    /// 获取缓存大小
    public func getCacheSize() -> String {
        modelManager?.formattedCacheSize ?? "0 B"
    }

    /// 清空缓存
    public func clearCache() throws {
        try modelManager?.clearAllCache()
        if Self.verbose {
            if Self.verbose {
                            Self.logger.info("\(self.t) 缓存已清空")
            }
        }
    }

    /// 本地模型下载目录（供设置页“打开下载目录”使用）
    public func getCacheDirectoryURL() -> URL {
        let url = cacheBaseModelsURL
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: - Helper Methods

    private var cacheBaseModelsURL: URL {
        MLXModels.modelsCacheBaseDirectory
    }

    private func cacheDirectory(for modelId: String) -> URL {
        MLXModels.cacheDirectory(for: modelId)
    }

    private func containsValidSafetensorsFiles(_ directory: URL) -> Bool {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return false
        }

        var totalSize: Int64 = 0
        let minValidSize: Int64 = 1_000_000

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "safetensors" else { continue }

            do {
                let values = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                guard values.isDirectory != true else { continue }
                if let size = values.fileSize {
                    totalSize += Int64(size)
                }
            } catch {
                continue
            }
        }

        return totalSize >= minValidSize
    }


    // MARK: - Transport

    public func streamChat(
        messages: [ChatMessage],
        config: LLMConfig,
        tools: [SuperAgentTool]?,
        maxThinkingLength: Int,
        onChunk: @escaping @Sendable (StreamChunk) async -> Void,
        onRequestStart: @escaping @Sendable (HTTPRequestMetadata) async -> Void
    ) async throws -> ChatMessage {
        try await LocalLLMProviderTransport.streamChat(
            provider: self,
            messages: messages,
            config: config,
            tools: tools,
            onChunk: onChunk
        )
    }

    public func sendMessage(
        messages: [ChatMessage],
        config: LLMConfig,
        tools: [SuperAgentTool]?
    ) async throws -> ChatMessage {
        try await LocalLLMProviderTransport.sendMessage(
            provider: self,
            messages: messages,
            config: config,
            tools: tools
        )
    }

    // MARK: - Availability

    public func availabilityCheckStrategy(forModel modelId: String) -> AvailabilityCheckStrategy {
        .chatPing()
    }
}

// MARK: - MLX Error

public enum MLXError: LocalizedError {
    case modelNotDownloaded
    case downloadFailed(String)
    case loadFailed(String)
    case inferenceNotReady
    case notSupported(String)

    public var errorDescription: String? {
        switch self {
        case .modelNotDownloaded:
            return "模型未下载，请先下载模型"
        case .downloadFailed(let msg):
            return "下载失败：\(msg)"
        case .loadFailed(let msg):
            return "加载失败：\(msg)"
        case .inferenceNotReady:
            return "推理服务未就绪"
        case .notSupported(let msg):
            return "不支持的操作：\(msg)"
        }
    }
}
