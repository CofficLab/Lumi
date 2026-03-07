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
/// - **MCP 集成**: 管理 MCP (Model Context Protocol) 服务器和工具
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
    nonisolated static let verbose = true

    // MARK: - Combine Publishers (状态变化通知)

    /// 工具列表变化通知
    ///
    /// 当工具列表（内置 + MCP）发生变化时发送。
    /// ViewModel 可以订阅此发布者来更新 UI。
    let toolsPublisher = PassthroughSubject<[AgentTool], Never>()
    
    /// MCP 配置列表变化通知（代理 MCPService）
    ///
    /// 当 MCP 服务器配置发生变化时发送。
    let mcpConfigsPublisher = PassthroughSubject<[MCPServerConfig], Never>()
    
    /// MCP 连接错误变化通知（代理 MCPService）
    ///
    /// 当 MCP 服务器连接发生错误时发送。
    /// 格式: [服务器名称: 错误信息]
    let mcpConnectionErrorsPublisher = PassthroughSubject<[String: String], Never>()
    
    /// MCP 连接客户端数量变化通知（代理 MCPService）
    ///
    /// 当 MCP 客户端连接数量变化时发送。
    let mcpConnectedClientsCountPublisher = PassthroughSubject<Int, Never>()

    // MARK: - Properties

    /// 所有可用工具（包括内置工具和 MCP 工具）
    ///
    /// 每次工具列表更新时都会重新计算。
    private(set) var allTools: [AgentTool] = []

    /// 内置工具列表
    ///
    /// Lumi 内置的核心工具集。
    private var builtInTools: [AgentTool] = []

    /// MCP 工具列表
    ///
    /// 从 MCP 服务器动态获取的工具。
    private var mcpTools: [AgentTool] = []

    // MARK: - Dependencies

    /// MCP 服务
    ///
    /// 负责管理 MCP 服务器连接和工具。
    private let mcpService: MCPService
    
    /// Shell 服务
    ///
    /// 负责执行 shell 命令。
    private let shellService: ShellService
    
    /// 权限服务
    ///
    /// 负责检查命令执行的权限和风险等级。
    private(set) var permissionService: PermissionService
    
    /// Combine 订阅集合
    ///
    /// 存储所有 Combine 订阅，用于清理。
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    /// 初始化工具服务
    ///
    /// 执行以下初始化步骤：
    /// 1. 创建依赖服务（MCP、Shell、Permission）
    /// 2. 注册内置工具
    /// 3. 设置 MCP 监听器
    /// 4. 刷新工具列表
    init() {
        self.mcpService = MCPService()
        self.shellService = ShellService()
        self.permissionService = PermissionService()
        setupBuiltInTools()
        setupMCPObservers()
        refreshAllTools()

        if Self.verbose {
            os_log("\(Self.t)✅ 工具服务已初始化，内置工具：\(self.builtInTools.count) 个")
        }
    }

    // MARK: - Setup

    /// 注册所有内置工具
    ///
    /// 初始化 Lumi 的核心工具集：
    /// - ListDirectoryTool: 列出目录内容
    /// - ReadFileTool: 读取文件内容
    /// - WriteFileTool: 写入文件
    /// - ShellTool: 执行 Shell 命令
    private func setupBuiltInTools() {
        builtInTools = [
            ListDirectoryTool(),
            ReadFileTool(),
            WriteFileTool(),
            ShellTool(),
        ]
    }

    /// 设置 MCP 工具监听器
    ///
    /// 订阅 MCP 服务的发布者，监听：
    /// - 工具列表变化
    /// - 配置变化
    /// - 连接错误
    /// - 客户端连接数
    private func setupMCPObservers() {
        // 监听 MCP 工具更新
        mcpService.toolsPublisher
            .sink { [weak self] mcpTools in
                guard let self = self else { return }
                self.mcpTools = mcpTools
                self.refreshAllTools()
            }
            .store(in: &cancellables)
        
        // 代理 MCPService 的其他 publishers
        mcpService.configsPublisher
            .sink { [weak self] configs in
                self?.mcpConfigsPublisher.send(configs)
            }
            .store(in: &cancellables)
        
        mcpService.connectionErrorsPublisher
            .sink { [weak self] errors in
                self?.mcpConnectionErrorsPublisher.send(errors)
            }
            .store(in: &cancellables)
        
        mcpService.connectedClientsPublisher
            .sink { [weak self] clients in
                self?.mcpConnectedClientsCountPublisher.send(clients.count)
            }
            .store(in: &cancellables)
    }

    /// 刷新所有工具列表
    ///
    /// 合并内置工具和 MCP 工具，通知观察者。
    private func refreshAllTools() {
        allTools = builtInTools + mcpTools
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

    /// 获取 MCP 工具数量
    var mcpToolCount: Int {
        return mcpTools.count
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

    /// 获取 MCP 工具名称
    ///
    /// - Returns: MCP 工具名称数组
    var mcpToolNames: [String] {
        return mcpTools.map { $0.name }
    }

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
                os_log("\(Self.t)  结果预览：\(resultPreview)")
            }

            return result
        } catch {
            os_log(.error, "\(Self.t)❌ 工具执行失败：\(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - MCP 相关（代理 MCPService）

    /// 获取 MCP 配置列表
    ///
    /// 返回所有已配置的 MCP 服务器。
    var mcpConfigs: [MCPServerConfig] {
        return mcpService.configs
    }

    /// 获取 MCP 连接错误
    ///
    /// 返回服务器名称到错误信息的映射。
    var mcpConnectionErrors: [String: String] {
        return mcpService.connectionErrors
    }

    /// 获取 MCP 连接客户端数量
    var mcpConnectedClientsCount: Int {
        return mcpService.connectedClients.count
    }

    /// 添加 MCP 服务器配置
    ///
    /// - Parameter config: MCP 服务器配置
    func addMCPConfig(_ config: MCPServerConfig) {
        mcpService.addConfig(config)
    }

    /// 移除 MCP 服务器配置
    ///
    /// - Parameter name: 配置名称
    func removeMCPConfig(name: String) {
        mcpService.removeConfig(name: name)
    }

    /// 安装 Vision MCP
    ///
    /// 安装视觉模型 MCP 工具。
    ///
    /// - Parameter apiKey: API 密钥
    func installVisionMCP(apiKey: String) {
        mcpService.installVisionMCP(apiKey: apiKey)
    }

    /// 连接所有 MCP 服务器
    func connectAllMCPServers() async {
        await mcpService.connectAll()
    }

    /// 更新 MCP 工具列表
    ///
    /// 重新从 MCP 服务器获取可用工具。
    func updateMCPTools() async {
        await mcpService.updateTools()
    }

    /// 获取 MCP 状态报告
    ///
    /// - Returns: MCP 服务状态报告字符串
    func getMCPStatusReport() -> String {
        return mcpService.getStatusReport()
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
        
        return permissionService.requiresPermission(toolName: toolName, arguments: arguments)
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
        return permissionService.requiresPermission(toolName: toolName, arguments: arguments)
    }

    /// 评估命令风险等级
    ///
    /// 评估 Shell 命令的危险程度。
    ///
    /// - Parameter command: Shell 命令
    /// - Returns: 风险等级
    func evaluateCommandRisk(command: String) -> CommandRiskLevel {
        return permissionService.evaluateCommandRisk(command: command)
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
