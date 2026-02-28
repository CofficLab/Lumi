import Foundation
import MagicKit
import OSLog
import Combine

/// 工具管理器：负责管理所有可用工具
/// 单例模式，确保全局唯一实例
@MainActor
class ToolManager: ObservableObject, SuperLog {
    
    // MARK: - Singleton
    
    static let shared = ToolManager()
    
    // MARK: - Logger
    
    nonisolated static let emoji = "🧰"
    nonisolated static let verbose = true
    
    // MARK: - Published Properties
    
    /// 所有可用工具（包括内置工具和 MCP 工具）
    @Published private(set) var allTools: [AgentTool] = []
    
    /// 内置工具
    private var builtInTools: [AgentTool] = []
    
    /// MCP 工具
    private var mcpTools: [AgentTool] = []
    
    // MARK: - Dependencies
    
    private let mcpService = MCPService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    /// 获取所有工具（只读）
    var tools: [AgentTool] {
        return allTools
    }
    
    /// 获取工具数量
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
    
    // MARK: - Initialization
    
    private init() {
        setupBuiltInTools()
        setupMCPObservers()
        refreshAllTools()
        
        if Self.verbose {
            os_log("\(Self.t)工具管理器已初始化")
            os_log("\(Self.t)内置工具: \(self.builtInTools.count) 个")
        }
    }
    
    // MARK: - Setup
    
    /// 注册所有内置工具
    private func setupBuiltInTools() {
        builtInTools = [
            ListDirectoryTool(),
            ReadFileTool(),
            WriteFileTool(),
            ShellTool(shellService: .shared),
        ]
        
        if Self.verbose {
            let toolNames = builtInTools.map { $0.name }.joined(separator: ", ")
            os_log("\(Self.t)已注册内置工具: \(toolNames)")
        }
    }
    
    /// 设置 MCP 工具监听器
    private func setupMCPObservers() {
        mcpService.$tools
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mcpTools in
                guard let self = self else { return }
                self.mcpTools = mcpTools
                self.refreshAllTools()
            }
            .store(in: &cancellables)
    }
    
    /// 刷新所有工具列表
    private func refreshAllTools() {
        allTools = builtInTools + mcpTools
        
        if Self.verbose {
            os_log("\(Self.t)工具列表已刷新 (总计: \(self.allTools.count) 个)")
        }
    }
    
    // MARK: - Public API
    
    /// 根据名称获取工具
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
    /// - Parameter name: 工具名称
    /// - Returns: 如果工具存在则返回 true
    func hasTool(named name: String) -> Bool {
        return tool(named: name) != nil
    }
    
    /// 获取所有工具名称
    /// - Returns: 工具名称数组
    var allToolNames: [String] {
        return allTools.map { $0.name }
    }
    
    /// 获取内置工具名称
    /// - Returns: 内置工具名称数组
    var builtInToolNames: [String] {
        return builtInTools.map { $0.name }
    }
    
    /// 获取 MCP 工具名称
    /// - Returns: MCP 工具名称数组
    var mcpToolNames: [String] {
        return mcpTools.map { $0.name }
    }
    
    /// 按名称搜索工具（支持模糊匹配）
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
    /// - Parameter name: 工具名称
    /// - Returns: 工具的描述，如果工具不存在则返回 nil
    func description(forTool name: String) -> String? {
        return tool(named: name)?.description
    }
    
    /// 获取工具输入模式
    /// - Parameter name: 工具名称
    /// - Returns: 工具的输入模式，如果工具不存在则返回 nil
    func inputSchema(forTool name: String) -> [String: Any]? {
        return tool(named: name)?.inputSchema
    }
    
    /// 执行工具
    /// - Parameters:
    ///   - name: 工具名称
    ///   - arguments: 工具参数
    /// - Returns: 执行结果
    /// - Throws: 如果工具不存在或执行失败则抛出错误
    func executeTool(named name: String, arguments: [String: Any]) async throws -> String {
        guard let tool = tool(named: name) else {
            throw ToolError.toolNotFound(name)
        }

        if Self.verbose {
            let argsPreview = arguments.keys.joined(separator: ", ")
            os_log("\(Self.t)⚙️ 执行工具: \(name)(\(argsPreview))")
        }

        do {
            let startTime = Date()
            // 转换 [String: Any] 到 [String: ToolArgument]
            let toolArguments = arguments.mapValues { ToolArgument($0) }
            let result = try await tool.execute(arguments: toolArguments)
            let duration = Date().timeIntervalSince(startTime)
            
            if Self.verbose {
                let resultPreview = result.count > 200 ? String(result.prefix(200)) + "..." : result
                os_log("\(Self.t)✅ 工具执行成功 (耗时: \(String(format: "%.2f", duration))s)")
                os_log("\(Self.t)  结果预览: \(resultPreview)")
            }
            
            return result
        } catch {
            os_log(.error, "\(Self.t)❌ 工具执行失败: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 打印工具统计信息
    func printStatistics() {
        os_log("\(Self.t)📊 工具统计:")
        os_log("\(Self.t)  总计: \(self.allTools.count) 个")
        os_log("\(Self.t)  内置: \(self.builtInTools.count) 个")
        os_log("\(Self.t)  MCP: \(self.mcpTools.count) 个")
        
        if !builtInTools.isEmpty {
            os_log("\(Self.t)  内置工具: \(self.builtInToolNames.joined(separator: ", "))")
        }
        
        if !mcpTools.isEmpty {
            os_log("\(Self.t)  MCP 工具: \(self.mcpToolNames.joined(separator: ", "))")
        }
    }
    
    // MARK: - Tool Categorization (可选)
    
    /// 获取文件操作相关工具
    var fileOperationTools: [AgentTool] {
        return allTools.filter { tool in
            tool.name.contains("file") ||
            tool.name.contains("read") ||
            tool.name.contains("write") ||
            tool.name.contains("ls")
        }
    }
    
    /// 获取 shell/命令相关工具
    var shellTools: [AgentTool] {
        return allTools.filter { tool in
            tool.name.contains("shell") ||
            tool.name.contains("command") ||
            tool.name.contains("run")
        }
    }
    
    /// 获取其他工具（非文件和 shell）
    var otherTools: [AgentTool] {
        let fileAndShellNames = fileOperationTools.map { $0.name } + shellTools.map { $0.name }
        return allTools.filter { !fileAndShellNames.contains($0.name) }
    }
}

// MARK: - Tool Error

enum ToolError: LocalizedError {
    case toolNotFound(String)
    case toolExecutionFailed(String, Error)
    
    var errorDescription: String? {
        switch self {
        case .toolNotFound(let name):
            return "Tool '\(name)' not found"
        case .toolExecutionFailed(let name, let error):
            return "Tool '\(name)' execution failed: \(error.localizedDescription)"
        }
    }
}
