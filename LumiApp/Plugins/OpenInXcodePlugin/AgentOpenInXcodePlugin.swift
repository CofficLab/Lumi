import MagicKit
import SwiftUI
import Foundation
import OSLog

/// 在 Xcode 中打开项目插件
///
/// 在 Agent 模式的 header 右侧添加一个按钮，点击后在 Xcode 中打开当前项目。
actor AgentOpenInXcodePlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    nonisolated static let emoji = "💻"

    nonisolated static let verbose: Bool = true

    static let id: String = "AgentOpenInXcode"
    static let displayName: String = String(localized: "Open in Xcode", table: "AgentOpenInXcode")
    static let description: String = String(localized: "Displays a button in the header to open the current project in Xcode", table: "AgentOpenInXcode")
    static let iconName: String = "hammer"
    static let isConfigurable: Bool = true
    static let enable: Bool = true
    static var order: Int { 95 }

    // MARK: - Instance

    nonisolated var instanceLabel: String { Self.id }
    static let shared = AgentOpenInXcodePlugin()

    // MARK: - Agent Views

    @MainActor
    func addRightHeaderTrailingItems() -> [AnyView] {
        [AnyView(OpenInXcodeButton())]
    }
}
