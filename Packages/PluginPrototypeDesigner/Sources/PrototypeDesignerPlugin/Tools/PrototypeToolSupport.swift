import Foundation
import KernelLumi

// MARK: - Errors

/// 工具执行过程中的可读错误。
enum PrototypeToolError: LocalizedError {
    case noProvider

    var errorDescription: String? {
        switch self {
        case .noProvider:
            "未检测到可用的 LLM Provider。请在设置中配置并启用至少一个模型供应商。"
        }
    }
}

// MARK: - Shared Helpers

/// 工具共享的辅助方法：JSON schema 构造、参数解析、内部 LLM 调用。
enum PrototypeToolSupport {
    /// 工具内部一次性调用 LLM（参考 `ReviewIconTool` 的 sub-agent 模式）。
    ///
    /// 走 `kernel.llmProvider.generateText`：不写入消息库、不触发 agent turn、
    /// 不污染当前对话历史，仅返回纯文本结果。
    @MainActor
    static func runGeneration(
        systemPrompt: String,
        userContent: String,
        kernel: KernelLumi
    ) async throws -> String {
        guard let manager = kernel.llmProvider else { throw PrototypeToolError.noProvider }
        let conversationID = PrototypeDesignerRuntime.shared.scratchConversationID
        let messages = [
            LumiChatMessage(conversationID: conversationID, role: .system, content: systemPrompt),
            LumiChatMessage(conversationID: conversationID, role: .user, content: userContent)
        ]
        // generateText 会用传入的 model 解析实际模型；request.model 仅占位。
        let request = LumiLLMRequest(messages: messages, model: manager.selectedModel ?? "scratch")
        return try await manager.generateText(
            request,
            providerID: manager.selectedProviderID,
            model: manager.selectedModel
        )
    }

    // MARK: - JSON Schema Helpers

    /// 构造一个 `string` 类型的 schema 属性。
    static func stringProperty(_ description: String) -> LumiJSONValue {
        .object([
            "type": .string("string"),
            "description": .string(description)
        ])
    }

    /// 构造一个 `string` + `enum` 的 schema 属性。
    static func enumProperty(_ description: String, values: [String]) -> LumiJSONValue {
        .object([
            "type": .string("string"),
            "description": .string(description),
            "enum": .array(values.map { .string($0) })
        ])
    }

    // MARK: - Argument Parsing

    /// 解析目标设备参数，缺失或非法时回退到 `.iphone`。
    static func device(from arguments: [String: LumiJSONValue]) -> PrototypeArtifact.Device {
        guard let raw = arguments.string("device"),
              let device = PrototypeArtifact.Device(rawValue: raw) else { return .iphone }
        return device
    }
}
