import Foundation
import LumiCoreKit

public final class CodexLumiProvider: LumiLLMProvider, @unchecked Sendable {
    public static let info = LumiLLMProviderInfo(
        id: "codex",
        displayName: LumiPluginLocalization.string("Codex", bundle: .module),
        description: LumiPluginLocalization.string("OpenAI models via Codex CLI", bundle: .module),
        defaultModel: "gpt-5.5",
        availableModels: ["gpt-5.5", "gpt-5.4-mini"],
        isLocal: true,
        contextWindowSizes: [
            "gpt-5.5": 1_000_000,
            "gpt-5.4-mini": 400_000
        ],
        modelCapabilities: [
            "gpt-5.5": .init(supportsVision: true, supportsTools: true),
            "gpt-5.4-mini": .init(supportsVision: true, supportsTools: true)
        ],
        websiteURL: URL(string: "https://github.com/openai/codex")!
    )

    private let cli: CodexCLI

    public init(cli: CodexCLI = CodexCLI()) {
        self.cli = cli
    }

    /// 本地 CLI 供应商无需 API Key
    public func lumiResolveAPIKey() throws -> String { "" }

    public func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        try await sendStreaming(request) { _ in }
    }

    public func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
        guard cli.isAvailable else {
            return .unavailable(.message("Codex CLI not found at \(cli.executablePath)"))
        }
        return .available
    }

    public func providerStatus() -> LumiLLMProviderStatus? {
        guard cli.isAvailable else {
            return LumiLLMProviderStatus(
                message: LumiPluginLocalization.string("Codex CLI not found", bundle: .module),
                level: .warning
            )
        }
        return nil
    }

    public func sendStreaming(
        _ request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage {
        guard let conversationID = request.messages.first?.conversationID else {
            throw CodexLumiError.missingConversation
        }

        guard cli.isAvailable else {
            throw CodexLumiError.cliNotFound(cli.executablePath)
        }

        let prompt = Self.buildPrompt(from: request.messages)
        let output = try await runCodexProcess(prompt: prompt, model: request.model)
        let parsed = CodexOutputParser.parse(output)

        guard !parsed.agentMessages.isEmpty else {
            let message = parsed.errors.first ?? parsed.nonJSONLines.first ?? "Empty Codex response"
            throw CodexLumiError.executionFailed(message)
        }

        let content = parsed.agentMessages.joined(separator: "\n\n")
        for chunk in Self.chunk(content) {
            await onChunk(LumiStreamChunk(content: chunk, eventTitle: "生成中"))
        }
        await onChunk(LumiStreamChunk(isDone: true, eventTitle: "结束"))

        return LumiChatMessage(
            conversationID: conversationID,
            role: .assistant,
            content: content,
            providerID: Self.info.id,
            modelName: request.model
        )
    }

    private func runCodexProcess(prompt: String, model: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: cli.executablePath)
            process.arguments = cli.arguments(prompt: prompt, model: model)

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            process.terminationHandler = { process in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                if process.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    continuation.resume(throwing: CodexLumiError.executionFailed(output))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private static func buildPrompt(from messages: [LumiChatMessage]) -> String {
        messages
            .filter { $0.role == .user || $0.role == .assistant || $0.role == .system }
            .map { message in
                let role = message.role.rawValue.uppercased()
                return "\(role): \(message.content)"
            }
            .joined(separator: "\n\n")
    }

    private static func chunk(_ text: String, size: Int = 4) -> [String] {
        guard !text.isEmpty else { return [] }
        var chunks: [String] = []
        var index = text.startIndex
        while index < text.endIndex {
            let end = text.index(index, offsetBy: size, limitedBy: text.endIndex) ?? text.endIndex
            chunks.append(String(text[index..<end]))
            index = end
        }
        return chunks
    }
}

enum CodexLumiError: LocalizedError {
    case missingConversation
    case cliNotFound(String)
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingConversation:
            return "Missing conversation ID"
        case .cliNotFound(let path):
            return "Codex CLI not found at \(path)"
        case .executionFailed(let message):
            return message
        }
    }
}
