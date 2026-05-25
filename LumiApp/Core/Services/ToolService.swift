import Foundation
import AgentToolKit
import Combine

/// 工具服务：负责管理所有可用工具
///
/// ToolService 是 Lumi 系统的工具管理中心，协调和管理所有 AI 可用的工具。
/// 作为 App 与 AgentToolKit 包之间的桥梁层。
///
/// ## 线程安全
///
/// 此类通过方法内部同步保证线程安全，因此可以安全地在并发代码中使用。
/// 所有操作都是异步的，不阻塞主线程。
class ToolService: SuperLog, @unchecked Sendable {

    // MARK: - Logger

    nonisolated static let emoji = "🧰"
    nonisolated static let verbose: Bool = true

    // MARK: - Properties

    /// 所有可用工具（原始，未本地化）
    private(set) var allTools: [SuperAgentTool] = []

    /// 当前语言偏好（由 LLMRequester 在每次请求前设置）
    var languagePreference: LanguagePreference = .english

    /// 插件提供的工具列表
    private var pluginTools: [SuperAgentTool] = []

    // MARK: - Dependencies

    /// LLM 服务（可选，传递给插件构建工具上下文）
    private let llmService: LLMService?

    /// LLM 配置 ViewModel（可选，由 RootContainer 注入）
    weak var llmVM: AppLLMVM? {
        didSet {
            Task { @MainActor [weak self] in
                self?.refreshAllTools()
            }
        }
    }

    /// 对话管理 ViewModel（可选，由 WindowContainer 注入）
    weak var conversationVM: WindowConversationVM?

    /// Combine 订阅集合
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Notification Observers

    private var pluginsDidLoadObserver: NSObjectProtocol?
    private var toolSourcesDidChangeObserver: NSObjectProtocol?

    // MARK: - Initialization

    @MainActor
    init(llmService: LLMService? = nil) {
        self.llmService = llmService
        setupPluginObservers()
        refreshAllTools()

        if Self.verbose {
            AppLogger.core.info("\(Self.t)✅ 工具服务已初始化，插件工具：\(self.pluginTools.count) 个")
        }
    }

    // MARK: - Setup

    @MainActor
    private func setupPluginObservers() {
        pluginsDidLoadObserver = NotificationCenter.default.addObserver(
            forName: .pluginsDidLoad,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshAllTools()
            }
        }

        toolSourcesDidChangeObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("toolSourcesDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshAllTools()
            }
        }
    }

    /// 刷新所有工具列表
    @MainActor
    private func refreshAllTools() {
        let context = ToolContext(toolService: self, llmService: llmService, llmVM: llmVM, conversationVM: conversationVM)
        pluginTools = AppPluginVM.shared.collectAgentTools(context: context)
        allTools = coreAgentTools() + pluginTools

        let definitions = AppPluginVM.shared.collectSubAgentDefinitions()
        Task {
            await SubAgentScheduler.shared.registerDefinitions(definitions)
        }
    }

    @MainActor
    private func coreAgentTools() -> [SuperAgentTool] {
        guard let llmService, let llmVM else {
            return []
        }

        return [
            SpawnSubAgentTool(llmService: llmService, llmVM: llmVM, toolService: self),
            CollectSubAgentTool(),
        ]
    }

    // MARK: - Public API

    /// 获取所有可用工具（已按语言偏好本地化）
    var tools: [SuperAgentTool] {
        allTools.map { LocalizedAgentTool(underlying: $0, language: languagePreference) }
    }

    /// 根据名称获取工具
    func tool(named name: String) -> SuperAgentTool? {
        let tool = allTools.first { $0.name == name }
        if Self.verbose && tool == nil {
            AppLogger.core.error("\(Self.t)❌ 工具 '\(name)' 未找到")
        }
        return tool
    }

    /// 根据工具名称和参数 JSON 获取面向用户的操作描述
    ///
    /// 通过工具的 `displayDescription(for:)` 方法获取描述，
    /// 工具未注册或未提供描述时返回 `nil`。
    func displayDescription(toolName: String, argumentsJSON: String) -> String? {
        guard let tool = tool(named: toolName),
              let dict = Self.parseToolArgumentsDict(from: argumentsJSON) else {
            return nil
        }
        let toolArgs = dict.mapValues { ToolArgument($0) }
        return tool.displayDescription(for: toolArgs)
    }

    /// 检查工具是否存在
    func hasTool(named name: String) -> Bool {
        tool(named: name) != nil
    }

    /// 执行工具（JSON 字符串参数版本）
    func executeTool(named name: String, argumentsJSON: String, context: ToolExecutionContext) async throws -> String {
        try await executeTool(
            named: name,
            arguments: Self.parseToolArguments(from: argumentsJSON),
            context: context
        )
    }

    /// 执行工具调用
    func executeTool(_ toolCall: ToolCall, context: ToolExecutionContext) async throws -> String {
        let startTime = Date()
        try context.checkCancellation()

        guard hasTool(named: toolCall.name) else {
            throw ToolExecutionError.toolNotFound(toolName: toolCall.name)
        }

        let result = try await executeTool(
            named: toolCall.name,
            argumentsJSON: toolCall.arguments,
            context: context
        )
        try context.checkCancellation()

        if Self.verbose {
            let duration = Date().timeIntervalSince(startTime)
            AppLogger.core.info("\(Self.t)✅ 工具 \(toolCall.name) 执行完成 (耗时：\(String(format: "%.2f", duration))s)")
        }

        return result
    }

    /// 执行工具
    func executeTool(named name: String, arguments: [String: Any], context: ToolExecutionContext) async throws -> String {
        guard let tool = tool(named: name) else {
            throw ToolError.toolNotFound(name)
        }

        if Self.verbose {
            let argsPreview = arguments.keys.joined(separator: ", ")
            AppLogger.core.info("\(Self.t)⚙️ 执行工具：\(name)(\(argsPreview))")
        }

        do {
            let startTime = Date()
            let toolArguments = arguments.mapValues { ToolArgument($0) }
            let result: String
            try context.checkCancellation()
            result = try await tool.execute(arguments: toolArguments, context: context)
            try context.checkCancellation()
            let duration = Date().timeIntervalSince(startTime)

            if Self.verbose {
                let resultPreview = result.count > 200 ? String(result.prefix(200)) + "..." : result
                AppLogger.core.info("\(Self.t)✅ 工具执行成功 (耗时：\(String(format: "%.2f", duration))s)")
                AppLogger.core.info("\(Self.t)📺 结果预览：\n\(resultPreview)")
            }

            return result
        } catch {
            AppLogger.core.error("\(Self.t)❌ 工具执行失败：\(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - 权限相关

    func requiresPermission(toolName: String, argumentsJSON: String?) -> Bool {
        let arguments = argumentsJSON.flatMap { Self.parseToolArgumentsDict(from: $0) }
        return requiresPermission(toolName: toolName, arguments: arguments)
    }

    func requiresPermission(toolName: String, arguments: [String: Any]?) -> Bool {
        guard let tool = tool(named: toolName) else { return false }
        let rawArgs = arguments ?? [:]
        let toolArgs = rawArgs.mapValues { ToolArgument($0) }
        return tool.permissionRiskLevel(arguments: toolArgs).requiresPermission
    }

    /// 评估命令风险等级；工具未注册或未声明时返回 `.high`。
    func evaluateRisk(toolName: String, argumentsJSON: String) -> CommandRiskLevel {
        let parsed = Self.parseToolArgumentsDict(from: argumentsJSON)
        if let declared = declaredRiskLevel(toolName: toolName, arguments: parsed ?? [:]) {
            return declared
        }
        return .high
    }

    /// 获取工具定义声明的风险等级；工具未注册时返回 `nil`。
    func declaredRiskLevel(toolName: String, arguments: [String: Any]?) -> CommandRiskLevel? {
        guard let tool = tool(named: toolName) else { return nil }
        let rawArgs = arguments ?? [:]
        let toolArgs = rawArgs.mapValues { ToolArgument($0) }
        return tool.permissionRiskLevel(arguments: toolArgs)
    }

    /// 将工具参数字符串尽量解析为对象；失败时返回 nil。
    static func parseToolArgumentsDict(from argumentsJSON: String) -> [String: Any]? {
        let trimmed = argumentsJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else {
            return nil
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }
        if let dict = json as? [String: Any] {
            return dict
        }
        if let str = json as? String,
           let innerData = str.data(using: .utf8),
           let inner = try? JSONSerialization.jsonObject(with: innerData) as? [String: Any] {
            return inner
        }
        return nil
    }

    private static func parseToolArguments(from argumentsJSON: String) -> [String: Any] {
        parseToolArgumentsDict(from: argumentsJSON) ?? [:]
    }

    deinit {
        if let pluginsDidLoadObserver {
            NotificationCenter.default.removeObserver(pluginsDidLoadObserver)
        }
        if let toolSourcesDidChangeObserver {
            NotificationCenter.default.removeObserver(toolSourcesDidChangeObserver)
        }
    }
}
