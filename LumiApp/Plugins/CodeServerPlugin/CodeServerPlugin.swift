import MagicKit
import SwiftUI

/// Code Server 插件
///
/// 通过 WKWebView 内嵌 code-server (localhost:8080) 提供完整 VS Code 编辑体验。
actor CodeServerPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    nonisolated static let emoji = "🖥️"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false

    static let id = "CodeServer"
    static let navigationId: String = "code-server"
    static let displayName = String(localized: "Code Server", table: "CodeServer")
    static let description = String(localized: "在 Lumi 中通过 code-server 使用完整的 VS Code 编辑体验", table: "CodeServer")
    static let iconName = "desktopcomputer"
    static let isConfigurable: Bool = false
    static var order: Int { 85 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = CodeServerPlugin()

    // MARK: - Lifecycle

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    // MARK: - UI

    /// 右侧栏
    nonisolated var panelNeedsSidebar: Bool { true }

    @MainActor
    func addPanelView() -> AnyView? {
        AnyView(CodeServerView())
    }

    // MARK: - Status Bar

    @MainActor
    func addStatusBarTrailingView() -> AnyView? {
        AnyView(CodeServerExtensionsStatusView())
    }
}
