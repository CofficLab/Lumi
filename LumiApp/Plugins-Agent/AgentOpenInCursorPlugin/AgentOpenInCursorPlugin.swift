import AppKit
import MagicKit
import SwiftUI

/// 在 Cursor 中打开项目插件
///
/// 在 Agent 模式的 header 右侧添加一个按钮，点击后在 Cursor 编辑器中打开当前项目。
actor AgentOpenInCursorPlugin: SuperPlugin {
    nonisolated static let emoji = "↗️"
    nonisolated static let verbose = false

    static let id = "AgentOpenInCursor"
    static let displayName = String(localized: "Open in Cursor", table: "AgentOpenInCursor")
    static let description = String(localized: "Open current project in Cursor editor", table: "AgentOpenInCursor")
    static let iconName = "chevron.left.forwardslash.chevron.right"
    static var order: Int { 82 }
    static let enable: Bool = true

    static let shared = AgentOpenInCursorPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    @MainActor
    func addRightHeaderTrailingItems() -> [AnyView] {
        [AnyView(OpenInCursorButton())]
    }
}