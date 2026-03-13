import Foundation
import MagicKit
import OSLog
import SwiftUI

/// 代码搜索插件
///
/// 提供代码搜索和文件查找相关的 Agent 工具。
actor CodeSearchPlugin: SuperPlugin, SuperLog {
    /// 日志标识符
    nonisolated static let emoji = "🔍"

    /// 是否启用详细日志
    nonisolated static let verbose = true

    // MARK: - Plugin Properties

    static let id: String = "CodeSearch"
    static let displayName: String = "Code Search"
    static let description: String = "提供代码搜索和文件查找的 Agent 工具。"
    static let iconName: String = "magnifyingglass"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 17 }

    static let shared = CodeSearchPlugin()

    private init() {}

    // MARK: - Agent Tool Factories

    @MainActor
    func agentToolFactories() -> [AnyAgentToolFactory] {
        [AnyAgentToolFactory(CodeSearchFactory())]
    }
}

// MARK: - Tools Factory

@MainActor
private struct CodeSearchFactory: AgentToolFactory {
    let id: String = "codesearch.factory"
    let order: Int = 0

    func makeTools(env: AgentToolEnvironment) -> [AgentTool] {
        [
            CodeSearchTool(),
            FindFilesTool(),
        ]
    }
}
