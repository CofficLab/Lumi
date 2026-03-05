import Foundation
import MagicKit
import OSLog

/// 后台任务调度器
///
/// 负责管理和调度所有后台任务，提供统一的执行入口
/// 确保耗时操作在后台线程执行，避免阻塞主线程
actor JobScheduler: SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "⏰"
    /// 是否输出详细日志
    nonisolated static let verbose = true

    /// 全局单例
    static let shared = JobScheduler()

    private init() {
        if Self.verbose {
            os_log("\(Self.t)后台任务调度器已初始化")
        }
    }

    // MARK: - 任务执行方法

    /// 执行 LLM 请求任务
    ///
    /// 自动在后台线程执行，不阻塞调用线程
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
        let input = LLMRequestJob.Input(
            messages: messages,
            config: config,
            tools: tools,
            registry: registry
        )

        return try await Task.detached(priority: .userInitiated) {
            try await LLMRequestJob.run(input)
        }.value
    }

    /// 执行工具调用任务
    ///
    /// 自动在后台线程执行，不阻塞调用线程
    ///
    /// - Parameters:
    ///   - toolCall: 工具调用信息
    ///   - toolManager: 工具管理器
    /// - Returns: 工具执行结果和耗时
    func executeToolCall(
        toolCall: ToolCall,
        toolManager: ToolManager
    ) async throws -> (ChatMessage, TimeInterval) {
        let input = ToolExecutionJob.Input(
            toolCall: toolCall,
            toolManager: toolManager
        )

        let output = try await Task.detached(priority: .userInitiated) {
            try await ToolExecutionJob.run(input)
        }.value

        return (output.result, output.duration)
    }

    /// 执行 JSON 解析任务
    ///
    /// 自动在后台线程执行，不阻塞调用线程
    ///
    /// - Parameter jsonString: JSON 字符串
    /// - Returns: 解析后的字典
    func parseJSON(_ jsonString: String) async -> [String: Any] {
        await Task.detached(priority: .utility) {
            await JSONParsingJob.parseToDictionary(jsonString)
        }.value
    }

    /// 执行 JSON 解析任务（AnySendable 版本）
    ///
    /// - Parameter jsonString: JSON 字符串
    /// - Returns: 解析后的 AnySendable 字典
    func parseJSONToSendable(_ jsonString: String) async -> [String: AnySendable] {
        await Task.detached(priority: .utility) {
            await JSONParsingJob.parseToSendable(jsonString)
        }.value
    }

    /// 解析工具调用参数
    ///
    /// - Parameter argumentsString: 工具调用参数字符串
    /// - Returns: 解析后的参数字典
    func parseToolArguments(_ argumentsString: String) async -> [String: Any] {
        await Task.detached(priority: .utility) {
            await JSONParsingJob.parseToolArguments(argumentsString)
        }.value
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
