import Foundation
import LumiCoreLLMProvider
import LumiCoreMessage
import SuperLogKit
import os

/// Mock `LumiLLMProvider` implementation.
///
/// Local, no network, no API key. Echoes the last user message back
/// as the assistant reply, with a small `[mock]` suffix.
///
/// Automatically detects if the user message contains keywords that
/// should trigger a mock tool call (天气/时间/搜索/计算).
public final class MockLLMProvider: LumiLLMProvider, @unchecked Sendable, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.llm-provider-manager.mock")
    public nonisolated static let emoji = "🧪"
    nonisolated(unsafe) public static var verbose = true

    public static let info = LumiLLMProviderInfo(
        id: "mock",
        displayName: "Mock Provider",
        description: "Local mock provider that echoes user input. Auto-detects weather/time/search/calc keywords to return mock tool calls.",
        defaultModel: "mock-default",
        availableModels: ["mock-default"],
        isLocal: true,
        contextWindowSizes: [
            "mock-default": 8_192
        ],
        modelCapabilities: [
            "mock-default": .init(supportsVision: false, supportsTools: true, supportsTTS: false)
        ],
        websiteURL: URL(string: "https://example.invalid/mock-provider")!
    )

    public init() {
        if Self.verbose {
            Self.logger.info("\(Self.t)\(Self.onInit)MockLLMProvider")
        }
    }

    // MARK: - API Key (not needed for local mock)

    public func lumiResolveAPIKey() throws -> String {
        throw LumiLLMProviderSupportError.missingAPIKey(Self.info.displayName)
    }

    public func hasApiKey() -> Bool { false }
    public func getApiKey() -> String { "" }
    public func setApiKey(_ apiKey: String) {}
    public func removeApiKey() {}

    // MARK: - Send / Stream

    public func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        try await sendStreaming(request) { _ in }
    }

    public func sendStreaming(
        _ request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage {
        let conversationID = request.messages.last?.conversationID ?? UUID()
        let lastUser = request.messages.last(where: { $0.role == .user })?.content ?? ""
        let lowerContent = lastUser.lowercased()

        // Auto-detect tool call needed
        let toolCall = detectToolCall(from: lowerContent, userMessage: lastUser)

        if let toolCall, toolCall.name != "none" {
            return try await handleToolRequest(
                toolCall: toolCall,
                conversationID: conversationID,
                request: request,
                onChunk: onChunk
            )
        }

        // Default: text-only response
        let reply = Self.composeReply(for: request)

        if Self.verbose {
            Self.logger.info("\(Self.t)sendStreaming ➡️ model=\(request.model), reply.len=\(reply.count)")
        }

        // Stream the reply
        let chunkSize = 8
        var offset = reply.startIndex
        while offset < reply.endIndex {
            let end = reply.index(offset, offsetBy: chunkSize, limitedBy: reply.endIndex) ?? reply.endIndex
            let piece = String(reply[offset..<end])
            await onChunk(LumiStreamChunk(content: piece, isDone: false, isThinking: false, eventTitle: "Mock thinking…"))
            offset = end
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        await onChunk(LumiStreamChunk(content: nil, isDone: true, eventTitle: "Mock done"))

        return LumiChatMessage(
            conversationID: conversationID,
            role: .assistant,
            content: reply,
            providerID: Self.info.id,
            modelName: request.model
        )
    }

    // MARK: - Tool Call Detection

    /// Detect if user message should trigger a tool call
    private func detectToolCall(from content: String, userMessage: String) -> LumiToolCall? {
        if content.contains("天气") || content.contains("weather") {
            return LumiToolCall(
                id: UUID().uuidString,
                name: "get_weather",
                arguments: #"{"city": "北京"}"#
            )
        } else if content.contains("时间") || content.contains("time") || content.contains("现在") {
            return LumiToolCall(
                id: UUID().uuidString,
                name: "get_time",
                arguments: #"{"timezone": "Asia/Shanghai"}"#
            )
        } else if content.contains("搜索") || content.contains("search") || content.contains("查找") {
            return LumiToolCall(
                id: UUID().uuidString,
                name: "web_search",
                arguments: #"{"query": "\#(userMessage)"}"#
            )
        } else if content.contains("计算") || content.contains("calc") || content.contains("数学") || content.contains("2+2") {
            return LumiToolCall(
                id: UUID().uuidString,
                name: "calculate",
                arguments: #"{"expression": "2 + 2"}"#
            )
        }
        return nil
    }

    // MARK: - Handle Tool Request

    private func handleToolRequest(
        toolCall: LumiToolCall,
        conversationID: UUID,
        request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage {
        let toolName = toolCall.name

        if Self.verbose {
            Self.logger.info("\(Self.t)Mock tool call detected: \(toolName)")
        }

        // Execute the mock tool
        let toolResult = executeMockTool(toolCall)

        // Stream the thought process
        let thought = "我需要调用 \(toolName) 工具来回答这个问题。"
        for chunk in streamText(thought) {
            await onChunk(chunk)
        }
        await onChunk(LumiStreamChunk(content: nil, isDone: true, eventTitle: "Mock done"))

        return LumiChatMessage(
            conversationID: conversationID,
            role: .assistant,
            content: "我已经调用了 \(toolName) 工具，这是结果：\(toolResult.content)",
            providerID: Self.info.id,
            modelName: request.model,
            toolCalls: [toolCall]
        )
    }

    /// Execute mock tool and return result
    private func executeMockTool(_ toolCall: LumiToolCall) -> LumiToolResult {
        switch toolCall.name {
        case "get_weather":
            return LumiToolResult(content: "🌤 北京今天天气晴，温度25°C，适合出行。", duration: 0.1)
        case "get_time":
            let now = Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy年MM月dd日 HH:mm:ss"
            return LumiToolResult(content: "🕐 当前时间是：\(formatter.string(from: now))", duration: 0.05)
        case "web_search":
            return LumiToolResult(content: "🔍 搜索结果：\n1. 第一个相关结果\n2. 第二个相关结果\n3. 第三个相关结果", duration: 0.2)
        case "calculate":
            return LumiToolResult(content: "🧮 计算结果：2 + 2 = 4", duration: 0.05)
        default:
            return LumiToolResult(content: "✅ 工具执行完成", duration: 0.1)
        }
    }

    /// Helper to stream text as chunks
    private func streamText(_ text: String) -> [LumiStreamChunk] {
        var chunks: [LumiStreamChunk] = []
        let chunkSize = 8
        var offset = text.startIndex

        while offset < text.endIndex {
            let end = text.index(offset, offsetBy: chunkSize, limitedBy: text.endIndex) ?? text.endIndex
            let piece = String(text[offset..<end])
            chunks.append(LumiStreamChunk(content: piece, isDone: false, isThinking: false, eventTitle: "Mock thinking…"))
            offset = end
        }
        return chunks
    }

    /// Compose a deterministic reply from the last user message.
    private static func composeReply(for request: LumiLLMRequest) -> String {
        let lastUser = request.messages.last(where: { $0.role == .user })?.content
            ?? request.messages.last?.content
            ?? ""
        let preview: String
        if lastUser.isEmpty {
            preview = "(no user input)"
        } else if lastUser.count <= 120 {
            preview = lastUser
        } else {
            preview = String(lastUser.prefix(120)) + "…"
        }
        return "(mock) \(preview) [mock]"
    }

    // MARK: - Availability / Status / Error

    public func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
        Self.info.availableModels.contains(model) ? .available
            : .unavailable(.unsupportedModel("Model '\(model)' is not provided by \(Self.info.displayName)"))
    }

    public func providerStatus() -> LumiLLMProviderStatus? {
        nil
    }

    public func retryDisposition(for error: Error, context: LumiLLMRetryContext) -> LumiLLMErrorDisposition {
        .nonRetryable
    }

    public func errorRenderKind(for error: Error) -> String? { nil }

    public func makeErrorMessage(
        conversationID: UUID,
        request: LumiLLMRequest,
        error: Error,
        disposition: LumiLLMErrorDisposition
    ) -> LumiChatMessage {
        LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "Mock provider error: \(error.localizedDescription)",
            providerID: Self.info.id,
            modelName: request.model,
            isError: true
        )
    }
}
