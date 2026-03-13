import MagicKit
import SwiftUI

/// Agent 输入插件 - 负责显示输入区域（编辑器、工具栏等）
actor AgentInputPlugin: SuperPlugin {
    nonisolated static let emoji = "✏️"
    nonisolated static let verbose = false

    static let id = "AgentInput"
    static let displayName = String(localized: "Agent Input", table: "DevAssistant")
    static let description = String(localized: "Agent input area", table: "DevAssistant")
    static let iconName = "textformat.abc"
    static var order: Int { 83 }
    static let enable = true
    static let shared = AgentInputPlugin()

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
