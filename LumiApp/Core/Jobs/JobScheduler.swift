import Foundation
import MagicKit
import OSLog

/// 后台任务调度器
///
/// 负责管理和调度所有后台任务，提供统一的执行入口
/// 确保耗时操作在后台线程执行，避免阻塞主线程
actor JobScheduler: SuperLog {
    /// 日志级别：0=禁用，1=基本，2=详细，3=调试
    nonisolated static let verbose = false

    /// 全局单例
    static let shared = JobScheduler()

    private init() {
        if Self.verbose {
            os_log("\(Self.t)✅ 后台任务调度器已初始化")
        }
    }

    // MARK: - 任务执行方法

    /// 执行 LLM 请求任务
    ///
    /// 在后台线程执行，不阻塞调用线程
    ///
    /// - Parameters:
    ///   - messages: 消息历史
    ///   - config: LLM 配置
    ///   - tools: 可用工具列表
    ///   - registry: 供应商注册表
    /// - Returns: AI 助手的响应消息
    func executeLLMRequest(
        messages: [ChatMessage],
        config: LLMConfig,
        tools: [AgentTool]?,
        registry: ProviderRegistry
    ) async throws -> ChatMessage {
        try await LLMRequestJob.run(
            messages: messages,
            config: config,
            tools: tools,
            registry: registry
        )
    }

    /// 执行工具调用任务
    ///
    /// 自动在后台线程执行，不阻塞调用线程
    ///
    /// - Parameters:
    ///   - toolCall: 工具调用信息
    ///   - toolService: 工具服务
    /// - Returns: 工具执行结果和耗时
    func executeToolCall(
        toolCall: ToolCall,
        toolService: ToolService
    ) async throws -> (ChatMessage, TimeInterval) {
        let output = try await ToolExecutionJob.run(
            toolCall: toolCall,
            toolService: toolService
        )
        // 解构 Output 为元组
        return (output.result, output.duration)
    }
}

// MARK: - 便捷扩展

extension JobScheduler {
    /// 检查工具是否需要权限
    ///
    /// 这是纯计算方法，不需要后台执行
    ///
    /// - Parameters:
    ///   - toolCall: 工具调用
    ///   - autoApproveRisk: 是否自动批准
    /// - Returns: 是否需要权限
    nonisolated func requiresPermission(_ toolCall: ToolCall, autoApproveRisk: Bool) -> Bool {
        ToolExecutionJob.requiresPermission(toolCall, autoApproveRisk: autoApproveRisk)
    }

    /// 评估工具风险等级
    ///
    /// 这是纯计算方法，不需要后台执行
    ///
    /// - Parameter toolCall: 工具调用
    /// - Returns: 风险等级
    nonisolated func evaluateRisk(_ toolCall: ToolCall) -> CommandRiskLevel {
        ToolExecutionJob.evaluateRisk(toolCall)
    }

    /// 创建权限请求
    ///
    /// 这是纯计算方法，不需要后台执行
    ///
    /// - Parameters:
    ///   - toolCall: 工具调用
    ///   - riskLevel: 风险等级
    /// - Returns: 权限请求对象
    nonisolated func createPermissionRequest(_ toolCall: ToolCall, riskLevel: CommandRiskLevel) -> PermissionRequest {
        ToolExecutionJob.createPermissionRequest(toolCall, riskLevel: riskLevel)
    }
}

// MARK: - JSON 解析辅助方法

extension JobScheduler {
    /// 解析工具调用参数
    ///
    /// JSON 解析是轻量级操作，不需要后台执行
    ///
    /// - Parameter argumentsString: 工具调用参数字符串
    /// - Returns: 解析后的参数字典
    nonisolated func parseToolArguments(_ argumentsString: String) -> [String: Any] {
        if let data = argumentsString.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return json
        }
        return [:]
    }
}