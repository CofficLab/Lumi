import Foundation
import ToolKit
import Combine

/// 工具服务：负责管理所有可用工具
///
/// ToolService 是 Lumi 系统的工具管理中心，协调和管理所有 AI 可用的工具。
/// 作为 App 与 ToolKit 包之间的桥梁层。
///
/// ## 线程安全
///
/// 此类通过方法内部同步保证线程安全，因此可以安全地在并发代码中使用。
/// 所有操作都是异步的，不阻塞主线程。
class ToolService: SuperLog, @unchecked Sendable {

    // MARK: - Logger

    nonisolated static let emoji = "🧰"
    nonisolated static let verbose: Bool = false

    // MARK: - Properties

    /// 所有可用工具（原始，未本地化）
    private(set) var allTools: [SuperAgentTool] = []

    /// 当前语言偏好（由 LLMRequester 在每次请求前设置）
    var languagePreference: LanguagePreference = .english

    /// 内置工具列表（当前为空，全部由插件提供）
    private var builtInTools: [SuperAgentTool] = []

    /// 插件提供的工具列表
    private var pluginTools: [SuperAgentTool] = []

    // MARK: - Dependencies

    /// LLM 服务（可选，传递给插件构建工具上下文）
    private let llmService: LLMService?

    /// LLM 配置 ViewModel（可选，由 RootContainer 注入）
    weak var llmVM: AppLLMVM?

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
            AppLogger.core.info("\(Self.t)✅ 工具服务已初始化，内置工具：\(self.builtInTools.count) 个, 插件工具：\(self.pluginTools.count) 个")
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
        allTools = builtInTools + pluginTools
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

    /// 检查工具是否存在
    func hasTool(named name: String) -> Bool {
        tool(named: name) != nil
    }

    /// 执行工具（JSON 字符串参数版本）
    func executeTool(named name: String, argumentsJSON: String, context: ToolExecutionContext? = nil) async throws -> String {
        let arguments: [String: Any]
        if let data = argumentsJSON.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            arguments = json
        } else {
            arguments = [:]
        }
        return try await executeTool(named: name, arguments: arguments, context: context)
    }

    /// 执行工具
    func executeTool(named name: String, arguments: [String: Any], context: ToolExecutionContext? = nil) async throws -> String {
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
            if let context {
                try context.checkCancellation()
                result = try await tool.execute(arguments: toolArguments, context: context)
                try context.checkCancellation()
            } else {
                result = try await tool.execute(arguments: toolArguments)
            }
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
        let arguments: [String: Any]?
        if let json = argumentsJSON,
           let data = json.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            arguments = parsed
        } else {
            arguments = nil
        }
        return requiresPermission(toolName: toolName, arguments: arguments)
    }

    func requiresPermission(toolName: String, arguments: [String: Any]?) -> Bool {
        guard let tool = tool(named: toolName) else { return false }
        let rawArgs = arguments ?? [:]
        let toolArgs = rawArgs.mapValues { ToolArgument($0) }
        return tool.permissionRiskLevel(arguments: toolArgs).requiresPermission
    }

    /// 获取工具定义声明的风险等级；工具未注册时返回 `nil`。
    func declaredRiskLevel(toolName: String, arguments: [String: Any]?) -> CommandRiskLevel? {
        guard let tool = tool(named: toolName) else { return nil }
        let rawArgs = arguments ?? [:]
        let toolArgs = rawArgs.mapValues { ToolArgument($0) }
        return tool.permissionRiskLevel(arguments: toolArgs)
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
