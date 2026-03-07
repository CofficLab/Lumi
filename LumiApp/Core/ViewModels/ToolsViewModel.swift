import Foundation
import Combine
import OSLog
import MagicKit

/// Tools ViewModel：为 UI 层提供工具服务状态
///
/// 设计原则：
/// - 在 @MainActor 上运行，安全更新 UI 状态
/// - 通过 @Published 属性暴露状态给 SwiftUI
/// - 通过 ToolService 监听工具状态
@MainActor
class ToolsViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "🧰"
    nonisolated static let verbose = true

    // MARK: - Published Properties (UI 状态)

    /// 所有 MCP 服务器配置
    @Published private(set) var configs: [MCPServerConfig] = []

    /// 可用的工具列表
    @Published private(set) var tools: [AgentTool] = []

    /// 连接错误信息
    @Published private(set) var connectionErrors: [String: String] = [:]

    /// 已连接的客户端数量（用于 UI 显示）
    @Published private(set) var connectedClientsCount: Int = 0

    // MARK: - Service

    let toolService: ToolService

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(toolService: ToolService) {
        self.toolService = toolService

        // 初始化状态
        self.configs = toolService.mcpConfigs
        self.tools = toolService.tools
        self.connectionErrors = toolService.mcpConnectionErrors
        self.connectedClientsCount = toolService.mcpConnectedClientsCount

        setupPublishers()

        if Self.verbose {
            os_log("\(Self.t)✅ Tools ViewModel 已初始化")
        }
    }

    // MARK: - Setup Publishers

    private func setupPublishers() {
        // 监听配置变化
        toolService.mcpConfigsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] configs in
                self?.configs = configs
                if Self.verbose {
                    os_log("\(Self.t)📋 配置列表已更新：\(configs.count) 个")
                }
            }
            .store(in: &cancellables)

        // 监听工具列表变化
        toolService.toolsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tools in
                self?.tools = tools
                if Self.verbose {
                    os_log("\(Self.t)🔧 工具列表已更新：\(tools.count) 个")
                }
            }
            .store(in: &cancellables)

        // 监听连接错误变化
        toolService.mcpConnectionErrorsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] errors in
                self?.connectionErrors = errors
                if Self.verbose {
                    os_log("\(Self.t)⚠️ 连接错误已更新：\(errors.count) 个")
                }
            }
            .store(in: &cancellables)

        // 监听客户端连接变化
        toolService.mcpConnectedClientsCountPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                self?.connectedClientsCount = count
                if Self.verbose {
                    os_log("\(Self.t)🔌 已连接客户端：\(count) 个")
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    /// 添加服务器配置
    /// - Parameter config: MCP 服务器配置
    func addConfig(_ config: MCPServerConfig) {
        toolService.addMCPConfig(config)
    }

    /// 移除服务器配置
    /// - Parameter name: 配置名称
    func removeConfig(name: String) {
        toolService.removeMCPConfig(name: name)
    }

    /// 安装 Vision MCP
    /// - Parameter apiKey: API 密钥
    func installVisionMCP(apiKey: String) {
        toolService.installVisionMCP(apiKey: apiKey)
    }

    /// 获取状态报告
    /// - Returns: 状态报告字符串
    func getStatusReport() -> String {
        toolService.getMCPStatusReport()
    }

    /// 重新连接所有服务器
    func reconnectAll() async {
        await toolService.connectAllMCPServers()
    }

    /// 刷新工具列表
    func refreshTools() async {
        await toolService.updateMCPTools()
    }
}
