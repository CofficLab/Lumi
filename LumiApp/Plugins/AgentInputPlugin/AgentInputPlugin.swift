import MagicKit
import SwiftUI
import os

/// Agent 输入插件 - 负责显示输入区域（编辑器、工具栏等）
actor AgentInputPlugin: SuperPlugin {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.input")

    nonisolated static let emoji = "✏️"
    nonisolated static let verbose: Bool = false
    static let id = "AgentInput"
    static let displayName = String(localized: "Agent Input", table: "AgentInput")
    static let description = String(localized: "Agent input area", table: "AgentInput")
    static let iconName = "textformat.abc"
    static var order: Int { 83 }
    nonisolated static let enable: Bool = true    static let shared = AgentInputPlugin()

    // MARK: - Lifecycle

    nonisolated func onRegister() {
        // Init
    }

    nonisolated func onEnable() {
        // Init
    }

    nonisolated func onDisable() {
        // Cleanup
    }

    // MARK: - UI

    @MainActor
    func addRightBottomView() -> AnyView? {
        return AnyView(InputView())
    }
}

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation("dev_assistant")
        .inRootView()
        .withDebugBar()
}
