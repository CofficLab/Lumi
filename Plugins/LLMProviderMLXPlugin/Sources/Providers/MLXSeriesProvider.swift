import Foundation
import AgentToolKit
import LLMKit
import LumiKernel

// MARK: - Platform Detection

/// 检查当前是否运行在 Apple Silicon Mac 上
/// MLX 仅支持 Apple Silicon，不支持 Intel Mac
private var isAppleSiliconMac: Bool {
    #if arch(arm64)
    return true
    #else
    return false
    #endif
}

// MARK: - MLXSeriesProviderBase

/// MLX 系列（品牌）供应商基类
///
/// 一次实例化对应一个品牌（Qwen / Llama / Mistral / DeepSeek / Gemma / Coder / Microsoft）。
/// 所有品牌共享同一个底层推理服务（`MLXInferenceService`）—— 同一进程只能加载一个本地模型，
/// 因此 `_inferenceService` / `idleTimer` 是 `static`，跨实例复用。
///
/// 子类只需重写 `static var info` 与提供无参 `init()`，其它逻辑全部继承。
@available(macOS 14.0, *)
open class MLXSeriesProviderBase: LumiLLMProvider, @unchecked Sendable {

    // MARK: - 共享运行时（所有系列共用同一个推理服务）

    /// 持久化的推理服务（跨对话复用模型，避免每次重新加载）
    private nonisolated(unsafe) static var _inferenceService: MLXInferenceService?
    /// 空闲卸载计时器：生成完成后 10 分钟无新请求则释放模型内存
    private nonisolated(unsafe) static var idleTimer: Task<Void, Never>?
    /// 空闲超时时间（纳秒）：10 分钟
    private static let idleTimeoutNanos: UInt64 = 600_000_000_000

    // MARK: - 实例字段

    public let registration: MLXModels.SeriesRegistration

    // MARK: - 构造

    public init(registration: MLXModels.SeriesRegistration) {
        self.registration = registration
    }

    // MARK: - LumiLLMProvider.info

    /// 子类必须重写：返回本系列对应的 Provider 元数据。
    ///
    /// 基类直接 fatalError，避免意外走 base 分支。子类通过 `override class var info` 提供。
    public class var info: LumiLLMProviderInfo {
        fatalError("子类必须重写 MLXSeriesProviderBase.info")
    }

    /// 根据 SeriesRegistration 计算对应的 LumiLLMProviderInfo（子类共用）
    public static func computeInfo(for registration: MLXModels.SeriesRegistration) -> LumiLLMProviderInfo {
        let available = MLXModels.availableModels(forSeries: registration.seriesName)
        let recommended = MLXModels.recommended(forSeries: registration.seriesName)

        let fallbackDefault = available.first?.id ?? recommended.first?.id ?? ""

        let capabilityLookup = Dictionary(uniqueKeysWithValues: recommended.map {
            ($0.id, LumiModelCapabilities(supportsVision: $0.supportsVision, supportsTools: $0.supportsTools))
        })
        let displayNameLookup = Dictionary(uniqueKeysWithValues: recommended.map {
            ($0.id, $0.displayName)
        })

        return LumiLLMProviderInfo(
            id: registration.providerID,
            displayName: registration.providerSlug,
            description: registration.providerDescription,
            defaultModel: fallbackDefault,
            availableModels: available.map(\.id),
            isLocal: true,
            contextWindowSizes: [:],
            modelCapabilities: capabilityLookup,
            modelDisplayNames: displayNameLookup,
            websiteURL: registration.websiteURL
        )
    }

    // MARK: - LumiLLMProvider 接口实现

    public func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        try await sendStreaming(request) { _ in }
    }

    public func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
        guard isAppleSiliconMac else {
            return .unavailable(.message("MLX 仅支持 Apple Silicon Mac，不支持 Intel Mac"))
        }
        if Self.info.availableModels.contains(model) {
            return .available
        }
        return .unavailable(.message("模型 \(model) 未注册或不可用"))
    }

    public func providerStatus() -> LumiLLMProviderStatus? {
        guard isAppleSiliconMac else {
            return LumiLLMProviderStatus(
                message: "MLX 仅支持 Apple Silicon Mac",
                level: .error,
                isBlocking: false
            )
        }
        return nil
    }

    public func errorRenderKind(for error: Error) -> String? {
        MLXErrorHandling.renderKind(for: error)
    }

    public func lumiResolveAPIKey() throws -> String { "" }
    public func hasApiKey() -> Bool { true }
    public func getApiKey() -> String { "" }
    public func setApiKey(_ apiKey: String) {}
    public func removeApiKey() {}

    public func retryDisposition(for error: Error, context: LumiLLMRetryContext) -> LumiLLMErrorDisposition {
        .nonRetryable
    }

    public func makeErrorMessage(
        conversationID: UUID,
        request: LumiLLMRequest,
        error: Error,
        disposition: LumiLLMErrorDisposition
    ) -> LumiChatMessage {
        let detail = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        return LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "",
            providerID: Self.info.id,
            modelName: request.model,
            isError: true,
            rawErrorDetail: detail,
            renderKind: errorRenderKind(for: error),
            metadata: disposition.metadataEntries
        )
    }

    public func sendStreaming(
        _ request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage {
        guard isAppleSiliconMac else {
            throw MLXLumiError.unsupportedPlatform
        }
        guard let conversationID = request.messages.first?.conversationID else {
            throw MLXLumiError.missingConversation
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        let stats = StreamingTokenStats()

        let result = try await Self.generate(
            request: request,
            stats: stats,
            onChunk: onChunk
        )

        let streamingDurationMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0

        var metadata = MessageTokenMetadata.metadata(
            inputTokens: nil,
            outputTokens: stats.outputTokenCount > 0 ? stats.outputTokenCount : nil
        )
        metadata.merge(
            MessagePerformanceMetadata.metadata(
                latencyMs: streamingDurationMs,
                timeToFirstTokenMs: stats.timeToFirstTokenMs,
                streamingDurationMs: streamingDurationMs
            )
        ) { _, new in new }

        return LumiChatMessage(
            conversationID: conversationID,
            role: .assistant,
            content: result,
            providerID: Self.info.id,
            modelName: request.model,
            metadata: metadata
        )
    }

    // MARK: - 推理核心（共享）

    @MainActor
    private static func generate(
        request: LumiLLMRequest,
        stats: StreamingTokenStats,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> String {
        let service: MLXInferenceService = {
            if let existing = _inferenceService {
                return existing
            }
            let s = MLXInferenceService()
            _inferenceService = s
            return s
        }()

        cancelIdleTimer()

        if service.currentModelId != request.model {
            if service.currentModelId != nil {
                service.unloadModel()
            }
            try await service.loadModel(id: request.model)
        }

        let preparedMessages = LumiVisionMessageSupport.preparedMessages(for: request)
        let mlxMessages = preparedMessages.compactMap { message -> MLXChatMessage? in
            switch message.role {
            case .system:
                return MLXChatMessage(role: .system, content: message.content)
            case .user:
                let images = message.images.map {
                    ImageAttachment(data: $0.data, mimeType: $0.mimeType)
                }
                return MLXChatMessage(role: .user, content: message.content, images: images)
            case .assistant:
                return MLXChatMessage(role: .assistant, content: message.content)
            case .tool, .error, .status, .unknown:
                return nil
            }
        }

        guard !mlxMessages.isEmpty else {
            throw MLXLumiError.emptyPrompt
        }

        let requestImages = request.imageAttachments.compactMap { attachment -> ImageAttachment? in
            guard let data = Data(base64Encoded: attachment.base64Data) else { return nil }
            return ImageAttachment(data: data, mimeType: attachment.mimeType)
        }

        var content = ""
        for await chunk in service.chat(messages: mlxMessages, images: requestImages) {
            switch chunk {
            case .text(let text):
                content += text
                stats.recordToken()
                await onChunk(LumiStreamChunk(content: text, eventTitle: "生成中"))
            case .error(let message):
                throw MLXLumiError.generationFailed(message)
            case .toolCall:
                break
            }
        }

        await onChunk(LumiStreamChunk(isDone: true, eventTitle: "结束"))

        startIdleTimer()

        return content
    }

    // MARK: - Idle Timer

    private static func cancelIdleTimer() {
        idleTimer?.cancel()
        idleTimer = nil
    }

    private static func startIdleTimer() {
        cancelIdleTimer()
        guard let service = _inferenceService else { return }
        idleTimer = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: idleTimeoutNanos)
                service.unloadModel()
            } catch {
                // 被取消，正常退出
            }
        }
    }
}

// MARK: - 向后兼容

/// 向后兼容：`MLXLumiProvider` 即 Qwen 系列实例。
/// 旧代码（测试、其它文件）继续用 `MLXLumiProvider()` 也能工作。
@available(macOS 14.0, *)
public typealias MLXLumiProvider = MLXQwenProvider

// MARK: - 流式 Token 统计

/// 流式生成期间的 token 统计（线程安全，供 @MainActor 闭包外读取）
private final class StreamingTokenStats: @unchecked Sendable {
    private let startTime = CFAbsoluteTimeGetCurrent()
    private var lock = os_unfair_lock_s()
    private var _outputTokenCount = 0
    private var _timeToFirstTokenMs: Double?

    func recordToken() {
        os_unfair_lock_lock(&lock)
        _outputTokenCount += 1
        if _timeToFirstTokenMs == nil {
            _timeToFirstTokenMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
        }
        os_unfair_lock_unlock(&lock)
    }

    var outputTokenCount: Int {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return _outputTokenCount
    }

    var timeToFirstTokenMs: Double? {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return _timeToFirstTokenMs
    }
}

// MARK: - 错误

enum MLXLumiError: LocalizedError {
    case missingConversation
    case emptyPrompt
    case generationFailed(String)
    case unsupportedPlatform

    var errorDescription: String? {
        switch self {
        case .missingConversation:
            return "Missing conversation ID"
        case .emptyPrompt:
            return "Prompt is empty"
        case .generationFailed(let message):
            return message
        case .unsupportedPlatform:
            return "MLX 仅支持 Apple Silicon Mac，不支持 Intel Mac"
        }
    }
}
