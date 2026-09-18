import Foundation
import KitLLM

/// Codex CLI 本地供应商。CLI 负责账号认证和实际请求，Lumi 负责转换 prompt
/// 并把最终结果以流式块回传给消息链路。
@MainActor
public final class CodexProvider: SuperLLMProvider, LLMStreamingProviding {
    public let providerID = "codex"
    public let providerInfo = LLMProviderInfo(
        id: "codex",
        displayName: "Codex",
        description: "通过 Codex CLI 使用 OpenAI 模型",
        defaultModel: "gpt-5.5",
        models: [
            LLMModelInfo(id: "gpt-5.5", contextWindowSize: 1_000_000, supportsVision: true, supportsTools: true),
            LLMModelInfo(id: "gpt-5.4-mini", contextWindowSize: 400_000, supportsVision: true, supportsTools: true),
        ],
        isLocal: true,
        websiteURL: URL(string: "https://github.com/openai/codex")
    )

    private let cli: CodexCLI

    public init(cli: CodexCLI = CodexCLI()) { self.cli = cli }

    public func complete(_ request: LLMRequest) async throws -> LLMResponse {
        guard cli.isAvailable else {
            throw LLMProviderError.providerUnavailable("Codex CLI not found at \(cli.executablePath)")
        }
        let model = request.model ?? providerInfo.defaultModel
        let output = try await run(
            prompt: Self.prompt(from: request.messages),
            model: model,
            reasoningEffort: request.reasoningEffort
        )
        let parsed = CodexOutputParser.parse(output)
        let content = parsed.agentMessages.joined(separator: "\n\n")
        guard !content.isEmpty else { throw LLMProviderError.emptyResponse }
        return LLMResponse(
            content: content,
            model: model,
            inputTokenCount: parsed.inputTokens,
            outputTokenCount: parsed.outputTokens
        )
    }

    public func streamComplete(
        _ request: LLMRequest,
        onChunk: @escaping @Sendable (LLMStreamChunk) async -> Void
    ) async throws -> LLMResponse {
        let response = try await complete(request)
        for chunk in Self.chunks(response.content, size: 4) {
            await onChunk(LLMStreamChunk(content: chunk, eventTitle: "生成中"))
        }
        await onChunk(LLMStreamChunk(isDone: true, eventTitle: "结束"))
        return response
    }

    private func run(prompt: String, model: String, reasoningEffort: String?) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: cli.executablePath)
            process.arguments = cli.arguments(prompt: prompt, model: model, reasoningEffort: reasoningEffort)
            process.standardOutput = pipe
            process.standardError = pipe
            process.terminationHandler = { process in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                if process.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    continuation.resume(throwing: LLMProviderError.providerUnavailable(output))
                }
            }
            do { try process.run() } catch { continuation.resume(throwing: error) }
        }
    }

    private static func prompt(from messages: [LLMMessage]) -> String {
        messages.compactMap { message in
            switch message.role {
            case .system: return "[System] \(message.content)"
            case .user: return "[User] \(message.content)"
            case .assistant: return "[Assistant] \(message.content)"
            case .tool: return "[Tool] \(message.content)"
            case .status, .error, .unknown: return nil
            }
        }.joined(separator: "\n\n")
    }

    private static func chunks(_ text: String, size: Int) -> [String] {
        guard !text.isEmpty else { return [] }
        var result: [String] = []
        var index = text.startIndex
        while index < text.endIndex {
            let end = text.index(index, offsetBy: size, limitedBy: text.endIndex) ?? text.endIndex
            result.append(String(text[index..<end]))
            index = end
        }
        return result
    }
}
