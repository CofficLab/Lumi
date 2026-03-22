import Foundation
import MagicKit
/// 工具执行服务
/// 负责处理工具调用的执行、权限检查和风险评估
///
/// ## 职责
/// - 检查工具执行权限
/// - 评估命令风险等级
/// - 执行工具调用
/// - 处理工具执行结果
///
/// ## 使用示例
///
/// ```swift
/// let executionService = ToolExecutionService(toolService: toolService)
///
/// // 检查是否需要权限
/// let requiresPermission = executionService.requiresPermission(
///     toolName: "shell",
///     arguments: "{\"command\": \"ls -la\"}"
/// )
///
/// // 执行工具
/// let result = try await executionService.executeTool(toolCall)
/// ```
final class ToolExecutionService: SuperLog, @unchecked Sendable {
    nonisolated static let emoji = "⚙️"
    nonisolated static let verbose = false

    // MARK: - 依赖

    /// 工具服务
    private let toolService: ToolService

    // MARK: - 初始化

    /// 使用工具服务初始化
    /// - Parameter toolService: 工具服务实例
    init(toolService: ToolService) {
        self.toolService = toolService
    }

    // MARK: - 权限检查

    /// 评估命令风险等级
    /// - Parameters:
    ///   - toolName: 工具名称
    ///   - arguments: 工具参数（JSON 字符串）
    /// - Returns: 风险等级
    ///
    /// - Note: `ToolService.allTools` 仅在主线程更新；从流式回调等非主线程调用时必须在 MainActor 上读注册表，否则可能误判为未注册。
    func evaluateRisk(toolName: String, arguments: String) async -> CommandRiskLevel {
        let parsed = Self.parseToolArgumentsDict(from: arguments)
        return await MainActor.run {
            if let declared = toolService.declaredRiskLevel(toolName: toolName, arguments: parsed ?? [:]) {
                return declared
            }
            return .high
        }
    }

    /// 将工具参数字符串尽量解析为对象；失败时返回 nil（由调用方用 `[:]` 回退）。
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
    ///
    /// - Parameter toolCall: 工具调用信息
    /// - Returns: 工具执行结果
    /// - Throws: 执行过程中的错误
    func executeTool(_ toolCall: ToolCall) async throws -> String {
        let startTime = Date()

        // 检查工具是否存在
        let hasTool = toolService.hasTool(named: toolCall.name)

        guard hasTool else {
            throw ToolExecutionError.toolNotFound(toolName: toolCall.name)
        }

        // 执行工具
        let result = try await toolService.executeTool(
            named: toolCall.name,
            argumentsJSON: toolCall.arguments
        )

        let duration = Date().timeIntervalSince(startTime)

        if Self.verbose {
            AppLogger.core.info("\(Self.t)✅ 工具 \(toolCall.name) 执行完成 (耗时：\(String(format: "%.2f", duration))s)")
        }

        return result
    }

    /// 创建错误消息
    /// - Parameters:
    ///   - toolCall: 工具调用
    ///   - error: 错误信息
    /// - Returns: 错误消息对象
    func createErrorMessage(for toolCall: ToolCall, error: Error) -> ChatMessage {
        let errorContent: String
        if let toolError = error as? ToolExecutionError {
            errorContent = toolError.localizedDescription
        } else {
            errorContent = "Error executing tool: \(error.localizedDescription)"
        }

        return ChatMessage(
            role: .tool,
            content: errorContent,
            toolCallID: toolCall.id
        )
    }

    /// 创建工具未找到的错误消息
    /// - Parameter toolCall: 工具调用
    /// - Returns: 错误消息对象
    func createToolNotFoundMessage(for toolCall: ToolCall) -> ChatMessage {
        ChatMessage(
            role: .tool,
            content: "Error: Tool '\(toolCall.name)' not found.",
            toolCallID: toolCall.id
        )
    }
}

// MARK: - 错误类型

/// 工具执行错误
enum ToolExecutionError: Error, LocalizedError {
    /// 工具未找到
    case toolNotFound(toolName: String)
    /// 执行失败
    case executionFailed(toolName: String, reason: String)
    /// 权限被拒绝
    case permissionDenied(toolName: String)

    var errorDescription: String? {
        switch self {
        case .toolNotFound(let toolName):
            return "Tool '\(toolName)' not found."
        case .executionFailed(let toolName, let reason):
            return "Failed to execute '\(toolName)': \(reason)"
        case .permissionDenied(let toolName):
            return "Permission denied for '\(toolName)'"
        }
    }
}
