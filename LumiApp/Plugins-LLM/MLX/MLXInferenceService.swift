import Foundation
import MagicKit
import OSLog
import Combine
import MLXLLM
@preconcurrency import MLXLMCommon

/// MLX 推理服务
///
/// 负责：
/// - 从本地缓存加载 MLX 模型
/// - 执行流式对话生成
/// - 支持工具调用
/// - 支持图片输入（VLM）
@available(macOS 14.0, *)
@MainActor
public final class MLXInferenceService: ObservableObject, SuperLog {
    nonisolated public static let emoji = "🧠"
    nonisolated static let verbose = true

    // MARK: - Published Properties

    /// 当前服务状态
    @Published public private(set) var state: LLMState = .idle

    /// 当前加载的模型 ID
    @Published public private(set) var currentModelId: String?

    /// 生成速度（tokens/秒）
    @Published public private(set) var tokensPerSecond: Double = 0

    // MARK: - Private Properties

    private var modelContainer: ModelContainer?
    private var generationTask: Task<Void, Never>?

    // MARK: - Initialization

    public init() {
        if Self.verbose {
            os_log("\(self.t)✅ MLX 推理服务已初始化")
        }
    }

    deinit {
        // 不在 deinit 中调用 unloadModel()，因其为 MainActor 隔离；释放时由引用计数回收资源。
        // 调用方应在释放前主动调用 unloadModel()。
    }

    // MARK: - Public Methods

    /// 加载模型
    public func loadModel(id: String) async throws {
        guard state != .loading else {
            throw InferenceError.alreadyLoading
        }

        updateState(.loading)
        self.currentModelId = id

        let cacheBase = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let components = id.split(separator: "/").map(String.init)
        let modelDir: URL
        if components.count >= 2 {
            modelDir = cacheBase
                .appendingPathComponent("models", isDirectory: true)
                .appendingPathComponent(components[0], isDirectory: true)
                .appendingPathComponent(components[1], isDirectory: true)
        } else {
            modelDir = cacheBase
                .appendingPathComponent("models", isDirectory: true)
                .appendingPathComponent(id, isDirectory: true)
        }

        guard FileManager.default.fileExists(atPath: modelDir.path) else {
            updateState(.error("模型未下载"))
            self.currentModelId = nil
            throw InferenceError.modelNotDownloaded
        }

        do {
            let configuration = ModelConfiguration(directory: modelDir)
            self.modelContainer = try await loadModelContainer(configuration: configuration)

            updateState(.ready)
            if Self.verbose {
                os_log("\(self.t)✅ 模型加载成功：\(id)")
            }
        } catch {
            updateState(.error(error.localizedDescription))
            throw InferenceError.loadFailed(error.localizedDescription)
        }
    }

    /// 卸载模型
    public func unloadModel() {
        generationTask?.cancel()
        generationTask = nil
        modelContainer = nil

        Task { @MainActor in
            self.state = .idle
            self.currentModelId = nil
            self.tokensPerSecond = 0
        }

        if Self.verbose {
            os_log("\(self.t)✅ 模型已卸载")
        }
    }

    /// 流式对话生成
    public func chat(
        messages: [MLXChatMessage],
        tools: [[String: Sendable]]? = nil,
        images: [ImageAttachment] = []
    ) -> AsyncStream<GenerationChunk> {
        let state = self.state
        let container = self.modelContainer
        return AsyncStream { continuation in
            guard state == .ready, let container = container else {
                continuation.yield(.error("模型未就绪"))
                continuation.finish()
                return
            }

            let task = Task { @MainActor [weak self] in
                guard let self = self else {
                    continuation.finish()
                    return
                }

                await self.updateState(.generating)
                self.tokensPerSecond = 0

                if Self.verbose {
                    os_log("\(self.t)✅ 流式连接已建立，开始接收数据...")
                }

                do {
                    // Build MLX Chat.Message array, attaching images to the last user message
                    // First, convert ImageAttachment Data to temporary file URLs
                    let tempImageURLs: [URL] = images.compactMap { img in
                        let tempDir = FileManager.default.temporaryDirectory
                        let ext = img.mimeType.contains("png") ? "png" : "jpg"
                        let url = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
                        try? img.data.write(to: url)
                        return url
                    }

                    let chatMessages: [Chat.Message] = messages.enumerated().map { index, msg in
                        let isLastUser = (msg.role == .user && index == messages.lastIndex(where: { $0.role == .user }))
                        switch msg.role {
                        case .user:
                            // Convert image URLs to UserInput.Image for VLM inference
                            let imageContents: [UserInput.Image] = isLastUser ? tempImageURLs.map { .url($0) } : []
                            if imageContents.isEmpty {
                                return .user(msg.content)
                            } else {
                                return .user(msg.content, images: imageContents)
                            }
                        case .assistant:
                            return .assistant(msg.content)
                        case .system:
                            return .system(msg.content)
                        }
                    }

                    let userInput = UserInput(chat: chatMessages, tools: tools)
                    let lmInput = try await container.prepare(input: userInput)
                    let parameters = GenerateParameters(temperature: 0.7)

                    let generateStream = try await container.generate(
                        input: lmInput,
                        parameters: parameters
                    )

                    var tokenCount = 0
                    let startTime = Date()

                    for await result in generateStream {
                        try Task.checkCancellation()

                        if let text = result.chunk {
                            continuation.yield(.text(text))
                            tokenCount += 1
                        }
                        if let toolCall = result.toolCall {
                            let mlxToolCall = MLXToolCall(
                                id: UUID().uuidString,
                                name: toolCall.function.name,
                                arguments: (try? JSONSerialization.data(withJSONObject: toolCall.function.arguments.mapValues { $0.anyValue })).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
                            )
                            continuation.yield(.toolCall(mlxToolCall))
                        }
                    }

                    // Calculate tok/s
                    let elapsed = Date().timeIntervalSince(startTime)
                    if elapsed > 0 {
                        self.tokensPerSecond = Double(tokenCount) / elapsed
                    }

                    self.updateState(.ready)

                } catch {
                    if !Task.isCancelled {
                        continuation.yield(.error("生成失败：\(error.localizedDescription)"))
                        self.updateState(.error(error.localizedDescription))
                    }
                }

                continuation.finish()
            }

            Task { @MainActor [weak self] in
                self?.generationTask = task
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// 停止生成
    public func stopGeneration() {
        generationTask?.cancel()
        generationTask = nil
        tokensPerSecond = 0
        if state == .generating {
            state = .ready
        }
    }

    // MARK: - Private Methods

    private func updateState(_ newState: LLMState) {
        self.state = newState
    }

    private func loadModelContainer(configuration: ModelConfiguration) async throws -> ModelContainer {
        // Try VLM first (for models with vision support), then fall back to LLM
        // The global loadModelContainer function tries MLXVLM first internally
        do {
            if Self.verbose {
                os_log("\(self.t)尝试加载 VLM 模型...")
            }
            let container = try await MLXLMCommon.loadModelContainer(configuration: configuration) { progress in
                // Progress callback - can be used for loading UI
            }
            if Self.verbose {
                os_log("\(self.t)✅ VLM 模型加载成功")
            }
            return container
        } catch {
            if Self.verbose {
                os_log("\(self.t)VLM 加载失败，尝试 LLM: \(error.localizedDescription)")
            }
        }

        // Fallback to LLM
        if Self.verbose {
            os_log("\(self.t)尝试加载 LLM 模型...")
        }
        let container = try await MLXLMCommon.loadModelContainer(configuration: configuration) { progress in
            // Progress callback
        }
        if Self.verbose {
            os_log("\(self.t)✅ LLM 模型加载成功")
        }
        return container
    }
}

// MARK: - LLM State

public enum LLMState: Equatable, Sendable {
    case idle, loading, ready, generating, error(String)

    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.ready, .ready), (.generating, .generating):
            return true
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - Generation Chunk

public enum GenerationChunk: Sendable {
    case text(String)
    case toolCall(MLXToolCall)
    case error(String)
}

// MARK: - MLX Chat Message (本地定义，避免依赖 MagicKit)
// Uses core ImageAttachment type for images

public struct MLXChatMessage: Sendable {
    public var role: Role
    public var content: String
    public var images: [ImageAttachment]

    public enum Role: String, Sendable {
        case system, user, assistant
    }

    public init(role: Role, content: String, images: [ImageAttachment] = []) {
        self.role = role
        self.content = content
        self.images = images
    }
}

// MARK: - MLX Tool Call (本地定义，避免依赖 MagicKit)

public struct MLXToolCall: Sendable {
    public var id: String
    public var name: String
    public var arguments: String

    public init(id: String, name: String, arguments: String) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }
}

// MARK: - Inference Error

public enum InferenceError: LocalizedError {
    case modelNotDownloaded
    case alreadyLoading
    case loadFailed(String)
    case generateFailed(String)
    case notReady

    public var errorDescription: String? {
        switch self {
        case .modelNotDownloaded: return "模型未下载"
        case .alreadyLoading: return "模型正在加载中"
        case .loadFailed(let msg): return "加载失败：\(msg)"
        case .generateFailed(let msg): return "生成失败：\(msg)"
        case .notReady: return "模型未就绪"
        }
    }
}
