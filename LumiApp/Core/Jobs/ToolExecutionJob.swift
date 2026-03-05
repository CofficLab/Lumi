import Foundation
import MagicKit
import OSLog

/// 工具执行任务
///
/// 负责在后台执行工具调用，包括文件操作、命令执行等
/// 封装了完整的工具执行流程，包括参数解析、工具查找和结果返回
struct ToolExecutionJob {
    /// 日志标识 emoji
    nonisolated static let emoji = "⚡"
    /// 是否输出详细日志
    nonisolated static let verbose = true
}

// MARK: - 任务参数

extension ToolExecutionJob {
    /// 任务输入参数
    struct Input {
        /// 工具调用信息
        let toolCall: ToolCall
        /// 工具管理器
        let toolManager: ToolManager
    }

    /// 任务输出结果
    struct Output {
        /// 工具执行结果消息
        let result: ChatMessage
        /// 执行耗时（秒）
        let duration: TimeInterval
    }
}

// MARK: - 任务执行

extension ToolExecutionJob {
    /// 执行工具调用任务
    ///
    /// - Parameters:
    ///   - toolCall: 工具调用信息
    ///   - toolManager: 工具管理器
    /// - Returns: 工具执行结果
    /// - Throws: 如果工具执行失败，抛出相应的错误
    static func run(
        toolCall: ToolCall,
        toolManager: ToolManager
    ) async throws -> Output {
        if verbose {
            os_log("\(emoji) 开始执行工具：\(toolCall.name)")
        }

        let startTime = Date()

        // 解析参数
        let arguments: [String: Any]
        if let data = toolCall.arguments.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            arguments = json
        } else {
            arguments = [:]
            os_log(.error, "\(emoji) 参数解析失败，使用空参数")
        }

        // 使用 ToolManager 查找工具
        guard await toolManager.hasTool(named: toolCall.name) else {
            os_log(.error, "\(emoji)❌ 工具 '\(toolCall.name)' 未找到")
            throw NSError(
                domain: "ToolExecutionJob",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Tool not found: \(toolCall.name)"]
            )
        }

        // 执行工具
        let result: String
        do {
            // 抑制数据竞争警告：arguments 是值类型，在 await 传递时已经完成复制
            nonisolated(unsafe) let unsafeArgs = arguments

            result = try await toolManager.executeTool(
                named: toolCall.name,
                arguments: unsafeArgs
            )
        } catch {
            os_log(.error, "\(emoji)❌ 工具执行失败：\(error.localizedDescription)")
            throw error
        }

        let duration = Date().timeIntervalSince(startTime)

        if Self.verbose {
            os_log("\(emoji)✅ 工具执行完成，耗时：\(String(format: "%.3f", duration))秒")
        }

        let resultMsg = ChatMessage(
            role: .user,
            content: result,
            toolCallID: toolCall.id
        )

        return Output(result: resultMsg, duration: duration)
    }
}

// MARK: - 工具权限检查

extension ToolExecutionJob {
    /// 检查工具是否需要权限
    ///
    /// 此方法是纯计算，可以在任何线程调用
    ///
    /// - Parameters:
    ///   - toolCall: 工具调用
    ///   - autoApproveRisk: 是否自动批准风险操作
    /// - Returns: 是否需要请求权限
    static func requiresPermission(_ toolCall: ToolCall, autoApproveRisk: Bool) -> Bool {
        let requiresPermission = PermissionService.shared.requiresPermission(
            toolName: toolCall.name,
            arguments: parseArguments(toolCall.arguments)
        )
        return requiresPermission && !autoApproveRisk
    }

    /// 评估工具风险等级
    ///
    /// - Parameter toolCall: 工具调用
    /// - Returns: 风险等级
    static func evaluateRisk(_ toolCall: ToolCall) -> CommandRiskLevel {
        if toolCall.name == "run_command" {
            let args = parseArguments(toolCall.arguments)
            if let command = args["command"] as? String {
                return PermissionService.shared.evaluateCommandRisk(command: command)
            }
        }
        return .medium
    }

    /// 创建权限请求
    ///
    /// - Parameters:
    ///   - toolCall: 工具调用
    ///   - riskLevel: 风险等级
    /// - Returns: 权限请求对象
    static func createPermissionRequest(_ toolCall: ToolCall, riskLevel: CommandRiskLevel) -> PermissionRequest {
        return PermissionRequest(
            toolName: toolCall.name,
            argumentsString: toolCall.arguments,
            toolCallID: toolCall.id,
            riskLevel: riskLevel
        )
    }

    // MARK: - 私有方法

    /// 解析工具调用参数
    private static func parseArguments(_ argumentsString: String) -> [String: Any] {
        if let data = argumentsString.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return json
        }
        return [:]
    }
}
