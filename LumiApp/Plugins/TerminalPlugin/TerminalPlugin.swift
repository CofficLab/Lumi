import SwiftUI
import TerminalCoreKit

actor TerminalPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    nonisolated static let emoji = "💻"
    nonisolated static let verbose: Bool = true

    static let id = "Terminal"
    static let navigationId: String = "terminal"
    static let displayName = String(localized: "Terminal", table: "Terminal")
    static let description = String(localized: "Native interactive terminal powered by SwiftTerm", table: "Terminal")
    static let iconName = "terminal"
    static var category: PluginCategory { .developerTool }
    static var order: Int { 90 }
    nonisolated static let policy: PluginPolicy = .optIn

    nonisolated var instanceLabel: String { Self.id }
    static let shared = TerminalPlugin()

    // MARK: - Lifecycle

    nonisolated func onRegister() {}

    nonisolated func onEnable() {}

    nonisolated func onDisable() {
        Task { @MainActor in
            TerminalTabsViewModel.shared.closeAllSessions()
        }
    }

    // MARK: - UI (Sidebar Panel)

    @MainActor
    func addPosterViews() -> [AnyView] {
        [
            PluginPosterSupport.poster(
                title: "原生终端",
                subtitle: "在 Lumi 内直接打开交互式终端，会话和项目工作流放在一起。",
                icon: Self.iconName,
                accent: .mint,
                metrics: [
                    PluginPosterSupport.metric("Tabs", "多会话"),
                    PluginPosterSupport.metric("PTY", "原生交互"),
                ],
                rows: ["项目目录启动", "多标签会话", "关闭时清理会话"],
                chips: ["开发工具", "终端", "SwiftTerm"]
            ),
        ]
    }

    @MainActor
    func addViewContainer() -> ViewContainerItem? {
        ViewContainerItem(id: Self.id, title: Self.displayName, icon: Self.iconName) {
            AnyView(TerminalMainView())
        }
    }
}
