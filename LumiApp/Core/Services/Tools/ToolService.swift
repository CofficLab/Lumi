import Foundation
import MagicKit
import OSLog
import Combine

/// 工具服务：负责管理所有可用工具
///
/// ToolService 是 Lumi 系统的工具管理中心，协调和管理所有 AI 可用的工具。
///
/// ## 功能概述
///
/// - **工具注册**: 管理内置工具和 MCP 工具
/// - **工具执行**: 提供统一的工具执行接口
/// - **权限管理**: 代理 PermissionService 进行权限检查
/// - **插件集成**: 插件负责提供工具；内核只关心 Tool 抽象
///
/// ## 架构说明
///
/// ```text
/// ToolService
/// ├── 内置工具 (Built-in Tools)
/// │   ├── ListDirectoryTool (列出目录)
/// │   ├── ReadFileTool (读取文件)
/// │   │   ├── WriteFileTool (写入文件)
/// │   │   └── ShellTool (执行命令)
/// │
/// └── MCP 工具 (MCP Tools)
///     ├── 动态从 MCP 服务器获取
///     └── 支持扩展的外部工具
/// ```
///
/// ## 线程安全
///
/// 此类通过方法内部同步保证线程安全，因此可以安全地在并发代码中使用。
/// 所有操作都是异步的，不阻塞主线程。
///
/// ## 使用示例
///
/// ```swift
/// let toolService = ToolService()
///
/// // 获取所有工具
/// let allTools = toolService.tools
///
/// // 执行工具
/// let result = try await toolService.executeTool(
///     named: "read_file",
///     arguments: ["path": "/Users/angel/test.swift"]
/// )
///
/// // 检查权限
/// let requiresPermission = toolService.requiresPermission(
///     toolName: "shell",
///     arguments: ["command": "rm -rf /"]
/// )
/// ```
class ToolService: SuperLog, @unchecked Sendable {

    // MARK: - Logger

    /// 日志标识符
    nonisolated static let emoji = "🧰"
    
    /// 是否启用详细日志
    nonisolated static let verbose = false

    // MARK: - Combine Publishers (状态变化通知)

    /// 工具列表变化通知
    ///
    /// 当工具列表（内置 + MCP）发生变化时发送。
    /// ViewModel 可以订阅此发布者来更新 UI。
    let toolsPublisher = PassthroughSubject<[AgentTool], Never>()
    
    // MARK: - Properties

    /// 所有可用工具（包括内置工具、MCP 工具和插件工具）
    ///
    /// 每次工具列表更新时都会重新计算。
    private(set) var allTools: [AgentTool] = []

    /// 内置工具列表（保留接口；当前建议将大部分工具迁移到插件提供）
    private var builtInTools: [AgentTool] = []

    /// 插件提供的工具列表
    private var pluginTools: [AgentTool] = []

    // MARK: - Dependencies
    
    /// Shell 服务
    ///
    /// 负责执行 shell 命令。
    private let shellService: ShellService
    
    /// LLM 服务（可选）
    ///
    /// 当可用时，用于启用 Worker 协作工具。
    private let llmService: LLMService?
    
    /// Combine 订阅集合
    ///
    /// 存储所有 Combine 订阅，用于清理。
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    /// 初始化工具服务
    ///
    /// 执行以下初始化步骤：
    /// 1. 创建依赖服务（Shell）
    /// 2. 注册内置工具
    /// 3. 设置插件工具监听
    /// 4. 刷新工具列表
    @MainActor
    init(llmService: LLMService? = nil) {
        self.shellService = ShellService()
        self.llmService = llmService
        setupPluginObservers()
        refreshAllTools()

        if Self.verbose {
            os_log("\(Self.t)✅ 工具服务已初始化，内置工具：\(self.builtInTools.count) 个, 插件工具：\(self.pluginTools.count) 个")
        }
    }

    // MARK: - Setup

    // 说明：原先 `setupBuiltInTools()` 已迁移到插件（见 `AgentCoreToolsPlugin`）。

    /// 设置插件工具监听
    ///
    /// 当插件加载完成时，刷新插件工具列表。
    @MainActor
    private func setupPluginObservers() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PluginsDidLoad"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshAllTools()
            }
        }

        NotificationCenter.default.addObserver(
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
    ///
    /// 合并内置工具、MCP 工具和插件工具，通知观察者。
    @MainActor
    private func refreshAllTools() {
        let env = AgentToolEnvironment(toolService: self, llmService: llmService)
        let directTools = PluginProvider.shared.getAgentTools()
        let factories = PluginProvider.shared.getAgentToolFactories()
        let factoryTools = factories.flatMap { $0.makeTools(env: env) }

        pluginTools = directTools + factoryTools
        allTools = builtInTools + pluginTools
        toolsPublisher.send(allTools)
    }

    // MARK: - Public API

    // MARK: - 工具相关

    /// 获取所有可用工具（只读）
    ///
    /// 返回完整的工具列表，包括内置和 MCP 工具。
    var tools: [AgentTool] {
        return allTools
    }

    /// 获取工具总数
    var toolCount: Int {
        return allTools.count
    }

    /// 获取内置工具数量
    var builtInToolCount: Int {
        return builtInTools.count
    }

    /// 根据名称获取工具
    ///
    /// - Parameter name: 工具名称
    /// - Returns: 匹配的工具，如果未找到则返回 nil
    func tool(named name: String) -> AgentTool? {
        let tool = allTools.first { $0.name == name }

        if Self.verbose && tool == nil {
            os_log(.error, "\(Self.t)❌ 工具 '\(name)' 未找到")
        }

        return tool
    }

    /// 检查工具是否存在
    ///
    /// - Parameter name: 工具名称
    /// - Returns: 如果工具存在则返回 true
    func hasTool(named name: String) -> Bool {
        return tool(named: name) != nil
    }

    /// 获取所有工具名称
    ///
    /// - Returns: 工具名称数组
    var allToolNames: [String] {
        return allTools.map { $0.name }
    }

    /// 获取内置工具名称
    ///
    /// - Returns: 内置工具名称数组
    var builtInToolNames: [String] {
        return builtInTools.map { $0.name }
    }

    // MARK: - Note
    // MCP 或其他协议型工具来源应由插件提供；ToolService 不再提供协议专用 API。

    /// 按名称搜索工具（支持模糊匹配）
    ///
    /// 在工具名称和描述中进行模糊搜索。
    ///
    /// - Parameter query: 搜索关键词
    /// - Returns: 匹配的工具数组
    func searchTools(query: String) -> [AgentTool] {
        let lowercaseQuery = query.lowercased()
        return allTools.filter { tool in
            tool.name.lowercased().contains(lowercaseQuery) ||
            tool.description.lowercased().contains(lowercaseQuery)
        }
    }

    /// 获取工具描述信息
    ///
    /// - Parameter name: 工具名称
    /// - Returns: 工具的描述，如果工具不存在则返回 nil
    func description(forTool name: String) -> String? {
        return tool(named: name)?.description
    }

    /// 获取工具输入模式
    ///
    /// 返回工具的 JSON Schema，用于 UI 生成输入表单。
    ///
    /// - Parameter name: 工具名称
    /// - Returns: 工具的输入模式，如果工具不存在则返回 nil
    func inputSchema(forTool name: String) -> [String: Any]? {
        return tool(named: name)?.inputSchema
    }

    /// 执行工具（JSON 字符串参数版本）
    ///
    /// 通过工具名称和 JSON 字符串参数执行工具。
    ///
    /// - Parameters:
    ///   - name: 工具名称
    ///   - argumentsJSON: 工具参数（JSON 字符串格式）
    /// - Returns: 执行结果字符串
    /// - Throws: 如果工具不存在或执行失败则抛出错误
    func executeTool(named name: String, argumentsJSON: String) async throws -> String {
        // 解析 JSON 字符串
        let arguments: [String: Any]
        if let data = argumentsJSON.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            arguments = json
        } else {
            arguments = [:]
        }
        
        return try await executeTool(named: name, arguments: arguments)
    }
    
    /// 执行工具
    ///
    /// 根据工具名称和参数执行对应的工具。
    /// 执行流程：
    /// 1. 查找工具
    /// 2. 记录执行开始
    /// 3. 转换参数类型
    /// 4. 执行工具
    /// 5. 记录执行结果和耗时
    ///
    /// - Parameters:
    ///   - name: 工具名称
    ///   - arguments: 工具参数字典
    /// - Returns: 执行结果字符串
    /// - Throws: 如果工具不存在或执行失败则抛出错误
    func executeTool(named name: String, arguments: [String: Any]) async throws -> String {
        // 查找工具
        guard let tool = tool(named: name) else {
            throw ToolError.toolNotFound(name)
        }

        if Self.verbose {
            let argsPreview = arguments.keys.joined(separator: ", ")
            os_log("\(Self.t)⚙️ 执行工具：\(name)(\(argsPreview))")
        }

        // 执行工具并记录耗时
        do {
            let startTime = Date()
            // 转换 [String: Any] 到 [String: ToolArgument]
            let toolArguments = arguments.mapValues { value in
                ToolArgument(value)
            }
            let result = try await tool.execute(arguments: toolArguments)
            let duration = Date().timeIntervalSince(startTime)

            if Self.verbose {
                let resultPreview = result.count > 200 ? String(result.prefix(200)) + "..." : result
                os_log("\(Self.t)✅ 工具执行成功 (耗时：\(String(format: "%.2f", duration))s)")
                os_log("\(Self.t)📺 结果预览：\n\(resultPreview)")
            }

            return result
        } catch {
            os_log(.error, "\(Self.t)❌ 工具执行失败：\(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - 权限相关（代理 PermissionService）

    /// 检查工具是否需要权限（JSON 字符串版本）
    ///
    /// - Parameters:
    ///   - toolName: 工具名称
    ///   - argumentsJSON: 参数字典的 JSON 字符串
    /// - Returns: 是否需要权限
    func requiresPermission(toolName: String, argumentsJSON: String?) -> Bool {
        // 解析 JSON 字符串
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
    
    /// 检查工具是否需要权限
    ///
    /// 判断执行给定工具是否需要用户授权。
    ///
    /// - Parameters:
    ///   - toolName: 工具名称
    ///   - arguments: 参数字典
    /// - Returns: 是否需要权限
    func requiresPermission(toolName: String, arguments: [String: Any]?) -> Bool {
        // 完全由具体工具自己决定风险等级与是否需要用户批准
        if let tool = tool(named: toolName) {
            let rawArgs = arguments ?? [:]
            let toolArgs = rawArgs.mapValues { ToolArgument($0) }
            if let risk = tool.permissionRiskLevel(arguments: toolArgs) {
                return risk.requiresPermission
            }
        }

        // 如果工具未声明风险，则视为不需要权限
        return false
    }

    /// 获取工具定义声明的风险等级（如果有）。
    func declaredRiskLevel(toolName: String, arguments: [String: Any]?) -> CommandRiskLevel? {
        guard let tool = tool(named: toolName) else { return nil }
        let rawArgs = arguments ?? [:]
        let toolArgs = rawArgs.mapValues { ToolArgument($0) }
        return tool.permissionRiskLevel(arguments: toolArgs)
    }

    // MARK: - Tool Categorization

    /// 获取文件操作相关工具
    ///
    /// 过滤出与文件操作相关的工具：
    /// - 包含 "file" 的工具
    /// - 包含 "read" 的工具
    /// - 包含 "write" 的工具
    /// - 包含 "ls" 的工具
    var fileOperationTools: [AgentTool] {
        return allTools.filter { tool in
            tool.name.contains("file") ||
            tool.name.contains("read") ||
            tool.name.contains("write") ||
            tool.name.contains("ls")
        }
    }

    /// 获取 shell/命令相关工具
    ///
    /// 过滤出与 Shell 命令相关的工具：
    /// - 包含 "shell" 的工具
    /// - 包含 "command" 的工具
    /// - 包含 "run" 的工具
    var shellTools: [AgentTool] {
        return allTools.filter { tool in
            tool.name.contains("shell") ||
            tool.name.contains("command") ||
            tool.name.contains("run")
        }
    }

    /// 获取其他工具（非文件和 shell）
    ///
    /// 排除文件操作和 Shell 命令后的其他工具。
    var otherTools: [AgentTool] {
        let fileAndShellNames = fileOperationTools.map { $0.name } + shellTools.map { $0.name }
        return allTools.filter { !fileAndShellNames.contains($0.name) }
    }
}

// MARK: - Tool Error

/// 工具执行错误
///
/// 定义工具执行过程中可能发生的错误类型。
enum ToolError: LocalizedError {
    /// 工具未找到
    case toolNotFound(String)
    
    /// 工具执行失败
    case toolExecutionFailed(String, Error)

    /// 错误描述
    var errorDescription: String? {
        switch self {
        case .toolNotFound(let name):
            return "Tool '\(name)' not found"
        case .toolExecutionFailed(let name, let error):
            return "Tool '\(name)' execution failed: \(error.localizedDescription)"
        }
    }
}
