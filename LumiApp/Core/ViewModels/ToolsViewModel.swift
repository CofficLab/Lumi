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

    /// 可用的工具列表
    @Published private(set) var tools: [AgentTool] = []

    // MARK: - Service

    let toolService: ToolService

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(toolService: ToolService) {
        self.toolService = toolService

        // 初始化状态
        self.tools = toolService.tools

        setupPublishers()

        if Self.verbose {
            os_log("\(Self.t)✅ Tools ViewModel 已初始化")
        }
    }

    // MARK: - Setup Publishers

    private func setupPublishers() {
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
    }

    // MARK: - Public Methods
}
