import Foundation
import ToolKit

/// 工具执行服务
/// 负责处理工具调用的执行、权限检查和风险评估
final class ToolExecutionService: SuperLog, @unchecked Sendable {
    nonisolated static let emoji = "⚙️"
    nonisolated static let verbose: Bool = false

    // MARK: - 依赖

    /// 工具服务
    private let toolService: ToolService

    // MARK: - 初始化

    init(toolService: ToolService) {
        self.toolService = toolService
    }

    // MARK: - 权限检查

    /// 评估命令风险等级
    func evaluateRisk(toolName: String, arguments: String) async -> CommandRiskLevel {
        let parsed = Self.parseToolArgumentsDict(from: arguments)
        return await MainActor.run {
            if let declared = toolService.declaredRiskLevel(toolName: toolName, arguments: parsed ?? [:]) {
                return declared
            }
            return .high
        }
    }

    /// 将工具参数字符串尽量解析为对象；失败时返回 nil
    private static func parseToolArgumentsDict(from arguments: String) -> [String: Any]? {
        let trimmed = arguments.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else {
            return nil
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }
        if let dict = json as? [String: Any] {
            return dict
        }
        // 部分响应把参数包成 JSON 字符串，顶层不是 object 时尝试再解一层
        if let str = json as? String,
           let innerData = str.data(using: .utf8),
           let inner = try? JSONSerialization.jsonObject(with: innerData) as? [String: Any] {
            return inner
        }
        return nil
    }

    // MARK: - 工具执行

    /// 执行工具调用
    func executeTool(_ toolCall: ToolCall, context: ToolExecutionContext? = nil) async throws -> String {
        let startTime = Date()
        try context?.checkCancellation()

        guard toolService.hasTool(named: toolCall.name) else {
            throw ToolExecutionError.toolNotFound(toolName: toolCall.name)
        }

        let result = try await toolService.executeTool(
            named: toolCall.name,
            argumentsJSON: toolCall.arguments,
            context: context
        )
        try context?.checkCancellation()

        let duration = Date().timeIntervalSince(startTime)

        if Self.verbose {
            AppLogger.core.info("\(Self.t)✅ 工具 \(toolCall.name) 执行完成 (耗时：\(String(format: "%.2f", duration))s)")
        }

        return result
    }

    /// 创建错误消息
    func createErrorMessage(for toolCall: ToolCall, error: Error, conversationId: UUID) -> ChatMessage {
        let errorContent: String
        if let toolError = error as? ToolExecutionError {
            errorContent = toolError.localizedDescription
        } else {
            errorContent = "Error executing tool: \(error.localizedDescription)"
        }

        return ChatMessage(
            role: .tool,
            conversationId: conversationId,
            content: errorContent,
            toolCallID: toolCall.id
        )
    }

    /// 创建工具未找到的错误消息
    func createToolNotFoundMessage(for toolCall: ToolCall, conversationId: UUID) -> ChatMessage {
        ChatMessage(
            role: .tool,
            conversationId: conversationId,
            content: "Error: Tool '\(toolCall.name)' not found.",
            toolCallID: toolCall.id
        )
    }
}
