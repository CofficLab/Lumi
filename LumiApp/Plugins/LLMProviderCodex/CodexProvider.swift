import Foundation
import AgentToolKit
import LumiCoreKit
import os

/// Codex CLI 供应商实现
///
/// 通过本地安装的 `codex` 命令行工具（codex exec --json）与 OpenAI 模型通信。
/// 使用 ChatGPT 账号认证，无需 API Key。
///
/// 遵循 `SuperLocalLLMProvider` 协议（类似 MLX），因为不走 HTTP API，
/// 而是通过 Process 子进程调用 Codex CLI。
///
/// ## 工作原理
///
/// 1. 将 ChatMessage[] 序列化为 prompt 文本
/// 2. 调用 `codex exec --json -m <model> "<prompt>"`
/// 3. 解析 JSONL 输出，提取 agent_message 中的文本
/// 4. 模拟流式输出（按小块增量推送）
final class CodexProvider: NSObject, SuperLLMProvider, SuperLocalLLMProvider, SuperLog, @unchecked Sendable {
    nonisolated static let emoji = "🔮"
    nonisolated static let verbose: Bool = true

    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "llm.codex")

    // MARK: - Provider Info

    static let id = "codex"
    static let displayName = "Codex"
    static let shortName = "CX"
    static let description = "通过 Codex CLI 使用 OpenAI 模型（ChatGPT 账号认证）"
    static let websiteURL: String? = "https://github.com/openai/codex"

    // MARK: - Configuration

    /// Codex 使用 ChatGPT 账号认证，不需要 API Key
    static let apiKeyStorageKey = ""

    static let defaultModel = "gpt-5.5"

    static let modelCatalog: [LLMModelCatalogItem] = [
        .init(id: "gpt-5.5", description: "GPT-5.5，OpenAI 最新旗舰模型", spec: .init(contextWindowSize: 1_000_000, supportsVision: true, supportsTools: true)),
        .init(id: "gpt-5.4", description: "GPT-5.4，高性能模型", spec: .init(contextWindowSize: 1_000_000, supportsVision: true, supportsTools: true)),
        .init(id: "gpt-5.3", description: "GPT-5.3，平衡型模型", spec: .init(contextWindowSize: 1_000_000, supportsVision: true, supportsTools: true)),
        .init(id: "gpt-5.3-codex", description: "GPT-5.3 Codex，代码优化版本", spec: .init(contextWindowSize: 1_000_000, supportsVision: true, supportsTools: true)),
        .init(id: "gpt-5.2", description: "GPT-5.2，高效模型", spec: .init(contextWindowSize: 1_000_000, supportsVision: true, supportsTools: true)),
        .init(id: "gpt-4o", description: "GPT-4o，OpenAI 多模态旗舰模型", spec: .init(contextWindowSize: 128_000, supportsVision: true, supportsTools: true)),
        .init(id: "gpt-4o-mini", description: "GPT-4o Mini，轻量高效版本", spec: .init(contextWindowSize: 128_000, supportsVision: true, supportsTools: true)),
        .init(id: "o3", description: "o3，OpenAI 推理模型", spec: .init(contextWindowSize: 200_000, supportsVision: true, supportsTools: true)),
        .init(id: "o4-mini", description: "o4-mini，轻量推理模型", spec: .init(contextWindowSize: 200_000, supportsVision: true, supportsTools: true)),
        .init(id: "gpt-4.1", description: "GPT-4.1，新一代模型", spec: .init(contextWindowSize: 1_000_000, supportsVision: true, supportsTools: true)),
        .init(id: "gpt-4.1-mini", description: "GPT-4.1 Mini，高效版本", spec: .init(contextWindowSize: 1_000_000, supportsVision: true, supportsTools: true)),
        .init(id: "gpt-4.1-nano", description: "GPT-4.1 Nano，极速版本", spec: .init(contextWindowSize: 1_000_000, supportsVision: true, supportsTools: true)),
    ]

    // MARK: - SuperLLMProvider HTTP 桩（Codex 不走 HTTP）

    var baseURL: String { "" }

    func buildRequest(url: URL, apiKey: String) -> URLRequest {
        URLRequest(url: url)
    }

    func buildRequestBody(
        messages: [ChatMessage],
        model: String,
        tools: [SuperAgentTool]?,
        systemPrompt: String
    ) throws -> [String: Any] {
        throw CodexError.notSupported("Codex 供应商使用 CLI 模式，请使用 sendMessage 或 streamChat")
    }

    func parseResponse(data: Data) throws -> (content: String, toolCalls: [AgentToolKit.ToolCall]?) {
        throw CodexError.notSupported("Codex 供应商使用 CLI 模式")
    }

    func buildStreamingRequestBody(
        messages: [ChatMessage],
        model: String,
        tools: [SuperAgentTool]?,
        systemPrompt: String
    ) throws -> [String: Any] {
        throw CodexError.notSupported("Codex 供应商使用 CLI 模式")
    }

    func parseStreamChunk(data: Data) throws -> StreamChunk? {
        nil
    }

    // MARK: - SuperLocalLLMProvider

    func streamChat(
        messages: [ChatMessage],
        model: String,
        tools: [SuperAgentTool]?,
        systemPrompt: String?,
        images: [ImageAttachment],
        onChunk: @Sendable (StreamChunk) async -> Void
    ) async throws -> ChatMessage {
        let startTime = CFAbsoluteTimeGetCurrent()
        let conversationId = messages.first?.conversationId ?? UUID()

        guard Self.isCodexAvailable() else {
            throw CodexError.cliNotFound
        }

        let prompt = Self.buildPrompt(from: messages, systemPrompt: systemPrompt ?? "")

        if Self.verbose {
            Self.logger.info("\(self.t)执行 codex exec --json -m \(model)")
        }

        let output = try await runCodexProcess(prompt: prompt, model: model)

        // 解析 JSONL 输出
        let agentMessages = Self.extractAgentMessages(from: output)
        let (inputTokens, outputTokens) = Self.extractUsage(from: output)
        let errors = Self.extractErrors(from: output)

        if agentMessages.isEmpty {
            if let firstError = errors.first {
                throw CodexError.executionFailed(firstError)
            }
            throw CodexError.emptyResponse
        }

        let finalContent = agentMessages.joined(separator: "\n\n")

        // 模拟流式输出：将完整文本拆分为小块逐步推送
        let chunks = splitIntoChunks(text: finalContent, chunkSize: 4)
        for chunk in chunks {
            await onChunk(StreamChunk(content: chunk, eventType: .textDelta))
        }

        // 推送完成信号（含 token 用量）
        await onChunk(StreamChunk(
            content: nil,
            isDone: true,
            inputTokens: inputTokens,
            outputTokens: outputTokens
        ))

        let latency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0

        return ChatMessage(
            role: .assistant,
            conversationId: conversationId,
            content: finalContent,
            providerId: Self.id,
            modelName: model,
            latency: latency,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            totalTokens: (inputTokens ?? 0) + (outputTokens ?? 0)
        )
    }

    func sendMessage(
        messages: [ChatMessage],
        model: String,
        tools: [SuperAgentTool]?,
        systemPrompt: String?,
        images: [ImageAttachment]
    ) async throws -> ChatMessage {
        let startTime = CFAbsoluteTimeGetCurrent()
        let conversationId = messages.first?.conversationId ?? UUID()

        guard Self.isCodexAvailable() else {
            throw CodexError.cliNotFound
        }

        let prompt = Self.buildPrompt(from: messages, systemPrompt: systemPrompt ?? "")

        if Self.verbose {
            Self.logger.info("\(self.t)执行 codex exec --json -m \(model)")
        }

        let output = try await runCodexProcess(prompt: prompt, model: model)

        let agentMessages = Self.extractAgentMessages(from: output)
        let (inputTokens, outputTokens) = Self.extractUsage(from: output)
        let errors = Self.extractErrors(from: output)

        if agentMessages.isEmpty {
            if let firstError = errors.first {
                throw CodexError.executionFailed(firstError)
            }
            throw CodexError.emptyResponse
        }

        let finalContent = agentMessages.joined(separator: "\n\n")
        let latency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0

        return ChatMessage(
            role: .assistant,
            conversationId: conversationId,
            content: finalContent,
            providerId: Self.id,
            modelName: model,
            latency: latency,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            totalTokens: (inputTokens ?? 0) + (outputTokens ?? 0)
        )
    }

    // MARK: - Local Model Management（Codex 无需管理模型，始终 ready）

    func getAvailableModels() async -> [LocalModelInfo] {
        Self.modelCatalog.map { item in
            LocalModelInfo(
                id: item.id,
                displayName: item.id,
                description: item.description,
                size: "CLI",
                minRAM: 0,
                expectedBytes: 0,
                supportsVision: item.spec.capabilities.supportsVision,
                supportsTools: item.spec.capabilities.supportsTools
            )
        }
    }

    func getCachedModels() async -> Set<String> {
        Set(Self.modelCatalog.map(\.id))
    }

    func downloadModel(id: String) async throws {
        // Codex 无需下载模型，CLI 使用云端模型
    }

    func loadModel(id: String) async throws {
        // Codex 无需加载模型，始终 ready
    }

    func unloadModel() async {
        // 无操作
    }

    func getDownloadStatus() -> LocalDownloadStatus {
        .completed
    }

    func getModelState() async -> LocalLLMState {
        // Codex CLI 如果存在则始终 ready
        Self.isCodexAvailable() ? .ready : .error("未找到 codex CLI")
    }

    func getLoadedModelId() async -> String? {
        // Codex 不维护加载状态，返回 nil
        nil
    }

    func getCacheDirectoryURL() -> URL {
        FileManager.default.temporaryDirectory
    }

    func displayName(forModelId modelId: String) -> String? {
        Self.modelCatalog.first(where: { $0.id == modelId })?.description
    }

    // MARK: - CLI Detection

    /// 检测 codex CLI 是否可用
    static func isCodexAvailable() -> Bool {
        let path = codexPath()
        return FileManager.default.isExecutableFile(atPath: path)
    }

    /// 获取 codex CLI 路径
    static func codexPath() -> String {
        // 优先使用 Homebrew 安装版本
        "/opt/homebrew/bin/codex"
    }

    // MARK: - Prompt Building

    /// 将消息列表转换为 Codex CLI 的 prompt 文本
    private static func buildPrompt(
        from messages: [ChatMessage],
        systemPrompt: String
    ) -> String {
        var parts: [String] = []

        if !systemPrompt.isEmpty {
            parts.append("[System] \(systemPrompt)")
        }

        for message in messages {
            guard message.shouldSendToLLM else { continue }

            switch message.role {
            case .system:
                parts.append("[System] \(message.content)")
            case .user:
                if let toolCallID = message.toolCallID {
                    parts.append("[Tool Result \(toolCallID)] \(message.content)")
                } else {
                    parts.append("[User] \(message.content)")
                }
            case .assistant:
                var text = message.content
                if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
                    let callsDesc = toolCalls.map { "\($0.name)(\($0.arguments))" }.joined(separator: "; ")
                    if !text.isEmpty {
                        text += "\n[Tool Calls: \(callsDesc)]"
                    } else {
                        text = "[Tool Calls: \(callsDesc)]"
                    }
                }
                if !text.isEmpty {
                    parts.append("[Assistant] \(text)")
                }
            case .tool:
                parts.append("[Tool] \(message.content)")
            case .status, .error, .unknown:
                break
            }
        }

        return parts.joined(separator: "\n\n")
    }

    // MARK: - Process Execution

    /// 运行 codex exec 进程并收集完整输出
    private func runCodexProcess(prompt: String, model: String) async throws -> String {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: Self.codexPath())
        process.arguments = [
            "exec",
            "--json",
            "-m", model,
            "-a", "never",
            "-s", "workspace-write",
            prompt
        ]
        process.standardOutput = pipe
        process.standardError = pipe

        if Self.verbose {
            let preview = String(prompt.prefix(80))
            Self.logger.info("\(self.t)启动: codex exec --json -m \(model) \"\(preview)...\"")
        }

        try process.run()

        // 使用 Task 异步等待进程完成
        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false

            func resumeOnce(with result: Result<String, Error>) {
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(with: result)
            }

            // 在后台线程等待进程退出
            DispatchQueue.global(qos: .userInitiated).async {
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                if process.terminationStatus != 0 && output.isEmpty {
                    resumeOnce(with: .failure(CodexError.executionFailed("codex exec 退出码: \(process.terminationStatus)")))
                } else {
                    resumeOnce(with: .success(output))
                }
            }
        }
    }

    // MARK: - JSONL Parsing

    /// 从 JSONL 输出中提取所有 agent_message 文本
    private static func extractAgentMessages(from jsonlOutput: String) -> [String] {
        var messages: [String] = []

        for line in jsonlOutput.split(separator: "\n") {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            let type = json["type"] as? String ?? ""

            if type == "item.completed",
               let item = json["item"] as? [String: Any],
               let itemType = item["type"] as? String,
               itemType == "agent_message",
               let text = item["text"] as? String {
                messages.append(text)
            }
        }

        return messages
    }

    /// 从 JSONL 输出中提取错误信息（忽略 Reconnecting 类消息）
    private static func extractErrors(from jsonlOutput: String) -> [String] {
        var errors: [String] = []

        for line in jsonlOutput.split(separator: "\n") {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            if json["type"] as? String == "error",
               let message = json["message"] as? String,
               !message.contains("Reconnecting") {
                errors.append(message)
            }
        }

        return errors
    }

    /// 从 JSONL 输出中提取 token 用量
    private static func extractUsage(from jsonlOutput: String) -> (inputTokens: Int?, outputTokens: Int?) {
        for line in jsonlOutput.split(separator: "\n").reversed() {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  json["type"] as? String == "turn.completed",
                  let usage = json["usage"] as? [String: Any] else {
                continue
            }
            return (usage["input_tokens"] as? Int, usage["output_tokens"] as? Int)
        }
        return (nil, nil)
    }

    // MARK: - Helpers

    /// 将文本拆分为指定字符数的块，模拟流式输出效果
    private func splitIntoChunks(text: String, chunkSize: Int) -> [String] {
        guard chunkSize > 0 else { return [text] }
        var chunks: [String] = []
        var currentIndex = text.startIndex
        while currentIndex < text.endIndex {
            let endIndex = text.index(currentIndex, offsetBy: chunkSize, limitedBy: text.endIndex) ?? text.endIndex
            chunks.append(String(text[currentIndex..<endIndex]))
            currentIndex = endIndex
        }
        return chunks
    }
}

// MARK: - Codex Error

enum CodexError: LocalizedError {
    case cliNotFound
    case notSupported(String)
    case executionFailed(String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .cliNotFound:
            return "未找到 codex CLI，请确认已安装 codex（brew install codex 或从 App Store 安装 Codex.app）"
        case .notSupported(let msg):
            return "不支持的操作：\(msg)"
        case .executionFailed(let msg):
            return "Codex 执行失败：\(msg)"
        case .emptyResponse:
            return "Codex 返回了空响应"
        }
    }
}

extension CodexProvider {
    // MARK: - Availability

    func availabilityCheckStrategy(forModel modelId: String) -> AvailabilityCheckStrategy {
        .chatPing()
    }
}
