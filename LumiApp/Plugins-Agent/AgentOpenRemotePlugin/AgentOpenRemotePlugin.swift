import MagicKit
import SwiftUI
import Foundation
import OSLog

/// 在浏览器中打开远程仓库插件
///
/// 在 Agent 模式的 header 右侧添加一个按钮，点击后在浏览器中打开当前项目的远程仓库地址。
actor AgentOpenRemotePlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    nonisolated static let emoji = "🌐"

    nonisolated static let verbose: Bool = true

    static let id: String = "AgentOpenRemote"
    static let displayName: String = String(localized: "Open Remote Repository", table: "AgentOpenRemote")
    static let description: String = String(localized: "Open current project's remote repository in browser", table: "AgentOpenRemote")
    static let iconName: String = "safari"
    static let isConfigurable: Bool = false
    static var order: Int { 90 }

    // MARK: - Instance

    nonisolated var instanceLabel: String { Self.id }
    static let shared = AgentOpenRemotePlugin()

    // MARK: - Agent Views

    @MainActor
    func addRightHeaderTrailingItems() -> [AnyView] {
        [AnyView(OpenRemoteButton())]
    }
}
