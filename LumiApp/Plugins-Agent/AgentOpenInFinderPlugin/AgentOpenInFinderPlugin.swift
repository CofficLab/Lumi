import AppKit
import MagicKit
import SwiftUI

/// 在 Finder 中打开项目插件
///
/// 在 Agent 模式的 header 右侧添加一个按钮，点击后在 Finder 中打开当前项目目录。
actor AgentOpenInFinderPlugin: SuperPlugin {
    nonisolated static let emoji = "📂"
    nonisolated static let verbose = false

    static let id = "AgentOpenInFinder"
    static let displayName = String(localized: "Open in Finder", table: "AgentOpenInFinder")
    static let description = String(localized: "Open current project in Finder", table: "AgentOpenInFinder")
    static let iconName = "folder"
    static var order: Int { 96 }

    /// 用户可在设置中启用/禁用此插件
    static var isConfigurable: Bool { true }

    static let enable: Bool = true

    static let shared = AgentOpenInFinderPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    @MainActor
    func addRightHeaderTrailingItems() -> [AnyView] {
        [AnyView(OpenInFinderButton())]
    }
}