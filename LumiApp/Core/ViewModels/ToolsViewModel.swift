import Foundation
import Combine
import OSLog
import MagicKit

/// Tools ViewModel：为 UI 层提供工具服务状态
///
/// 设计原则：
/// - 在 @MainActor 上运行，安全更新 UI 状态
/// - 通过 @Published 属性暴露状态给 SwiftUI
/// - 监听 ToolService 的 Publishers 来同步状态
@MainActor
class ToolsViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "🔧"
    nonisolated static let verbose = true

    // MARK: - Published Properties (UI 状态)

    /// 所有可用工具
    @Published private(set) var allTools: [AgentTool] = []

    /// 工具数量
    @Published private(set) var toolCount: Int = 0

    /// 内置工具数量
    @Published private(set) var builtInToolCount: Int = 0

    /// MCP 工具数量
    @Published private(set) var mcpToolCount: Int = 0

    // MARK: - Service

    let service: ToolService

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(service: ToolService) {
        self.service = service

        // 初始化状态
        self.allTools = service.allTools
        self.toolCount = service.toolCount
        self.builtInToolCount = service.builtInToolCount
        self.mcpToolCount = service.mcpToolCount

        setupPublishers()

        if Self.verbose {
            os_log("\(Self.t)✅ Tools ViewModel 已初始化，工具总数：\(self.toolCount)")
        }
    }

    // MARK: - Setup Publishers

    private func setupPublishers() {
        // 监听工具列表变化
        service.toolsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tools in
                self?.allTools = tools
                self?.toolCount = tools.count
                self?.builtInToolCount = self?.service.builtInToolCount ?? 0
                self?.mcpToolCount = self?.service.mcpToolCount ?? 0
                if Self.verbose {
                    os_log("\(Self.t)🔧 工具列表已更新：\(tools.count) 个")
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    /// 根据名称获取工具
    /// - Parameter name: 工具名称
    /// - Returns: 匹配的工具，如果未找到则返回 nil
    func tool(named name: String) -> AgentTool? {
        service.tool(named: name)
    }

    /// 检查工具是否存在
    /// - Parameter name: 工具名称
    /// - Returns: 如果工具存在则返回 true
    func hasTool(named name: String) -> Bool {
        service.hasTool(named: name)
    }

    /// 获取所有工具名称
    var allToolNames: [String] {
        service.allToolNames
    }

    /// 按名称搜索工具
    /// - Parameter query: 搜索关键词
    /// - Returns: 匹配的工具数组
    func searchTools(query: String) -> [AgentTool] {
        service.searchTools(query: query)
    }

    /// 获取工具描述
    /// - Parameter name: 工具名称
    /// - Returns: 工具描述
    func description(forTool name: String) -> String? {
        service.description(forTool: name)
    }

    /// 执行工具
    /// - Parameters:
    ///   - name: 工具名称
    ///   - arguments: 工具参数
    /// - Returns: 执行结果
    func executeTool(named name: String, arguments: [String: Any]) async throws -> String {
        // ToolService 已经是 @unchecked Sendable，可以直接调用
        // arguments 在调用期间不会被修改，安全传递
        nonisolated(unsafe) let unsafeArguments = arguments
        return try await service.executeTool(named: name, arguments: unsafeArguments)
    }

    // MARK: - Tool Categories

    /// 文件操作相关工具
    var fileOperationTools: [AgentTool] {
        service.fileOperationTools
    }

    /// Shell/命令相关工具
    var shellTools: [AgentTool] {
        service.shellTools
    }

    /// 其他工具
    var otherTools: [AgentTool] {
        service.otherTools
    }
}
