import Foundation

/// 单次工具调用的取消上下文。
///
/// 和 Swift `Task.cancel()` 不同，这个上下文会显式传入工具内部，让工具可以把取消
/// 转发给底层资源（如 `Process.terminate()`、`WKWebView.stopLoading()` 或外部 SDK）。
final class ToolExecutionContext: @unchecked Sendable {
    typealias CancellationHandler = @Sendable () -> Void

    let conversationId: UUID
    let toolCallId: String
    let toolName: String

    private let lock = NSLock()
    private var cancelled = false
    private var handlers: [UUID: CancellationHandler] = [:]

    init(conversationId: UUID, toolCallId: String, toolName: String) {
        self.conversationId = conversationId
        self.toolCallId = toolCallId
        self.toolName = toolName
    }

    var isCancelled: Bool {
        lock.lock()
        let value = cancelled
        lock.unlock()
        return value || Task.isCancelled
    }

    func checkCancellation() throws {
        if isCancelled {
            throw CancellationError()
        }
    }

    @discardableResult
    func onCancel(_ handler: @escaping CancellationHandler) -> UUID? {
        lock.lock()
        if cancelled {
            lock.unlock()
            handler()
            return nil
        }
        let id = UUID()
        handlers[id] = handler
        lock.unlock()
        return id
    }

    func removeCancellationHandler(_ id: UUID?) {
        guard let id else { return }
        lock.lock()
        handlers[id] = nil
        lock.unlock()
    }

    func cancel() {
        let handlersToRun: [CancellationHandler]
        lock.lock()
        guard !cancelled else {
            lock.unlock()
            return
        }
        cancelled = true
        handlersToRun = Array(handlers.values)
        handlers.removeAll()
        lock.unlock()

        for handler in handlersToRun {
            handler()
        }
    }
}

/// 工具风险等级元数据由插件定义，内核只消费结果。

/// 代理工具协议
///
/// 定义 LLM 可以调用的工具/函数接口。
/// 工具允许 AI 助手执行特定操作，如读写文件、执行命令等。
///
/// ## 工具定义
///
/// 每个工具需要实现：
/// - `name`: 唯一名称，用于 AI 选择工具
/// - `description`: 功能描述，帮助 AI 理解何时使用
/// - `inputSchema`: 输入参数的 JSON Schema
/// - `permissionRiskLevel`: 当前调用的风险等级（必填）
/// - `execute`: 实际执行工具逻辑
///
/// ## 使用示例
///
/// ```swift
/// /// 读取文件工具
/// struct ReadFileTool: SuperAgentTool {
///     let name = "read_file"
///     let description = "读取指定路径的文件内容"
///     
///     var inputSchema: [String: Any] {
///         [
///             "type": "object",
///             "properties": [
///                 "path": [
///                     "type": "string",
///                     "description": "文件路径"
///                 ]
///             ],
///             "required": ["path"]
///         ]
///     }
///     
///     func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
///         .low
///     }
///
///     func execute(arguments: [String: ToolArgument]) async throws -> String {
///         let path = arguments["path"]?.value as? String ?? ""
///         return try String(contentsOfFile: path)
///     }
/// }
/// ```
protocol SuperAgentTool: Sendable {
    /// 工具名称
    ///
    /// 唯一标识符，AI 通过名称选择要执行的工具。
    /// 建议使用下划线命名法，如 "read_file", "run_command"
    var name: String { get }
    
    /// 工具描述
    ///
    /// 详细描述工具的功能、用途和使用场景。
    /// AI 根据描述判断是否需要调用此工具。
    /// 建议包含：
    /// - 工具用途
    /// - 输入参数含义
    /// - 返回值说明
    var description: String { get }
    
    /// 输入参数 JSON Schema
    ///
    /// 定义工具接受的参数格式。
    /// 使用 JSON Schema 格式，便于 AI 理解和生成正确参数。
    var inputSchema: [String: Any] { get }
    
    /// 执行工具
    ///
    /// 实际执行工具逻辑的方法。
    /// 接收参数字典，执行相应操作，返回结果字符串。
    ///
    /// - Parameter arguments: 符合 inputSchema 的参数字典
    /// - Returns: 执行结果，以字符串形式返回
    ///
    /// - Throws: 执行过程中可能抛出的错误
    func execute(arguments: [String: ToolArgument]) async throws -> String

    /// 带取消上下文的执行入口。
    ///
    /// 新工具应优先实现这个方法，把 `context` 传给底层长耗时操作。旧工具可以继续只实现
    /// `execute(arguments:)`；默认实现会在调用前后检查取消。
    func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String

    /// 工具自行评估当前调用的风险等级（必填，禁止省略）。
    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel
}

extension SuperAgentTool {
    func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        try context.checkCancellation()
        let result = try await execute(arguments: arguments)
        try context.checkCancellation()
        return result
    }
}
