import SwiftUI
import LumiUI
import LumiCoreKit
import SuperLogKit
import TerminalCoreKit

public actor TerminalPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    public nonisolated static let emoji = "💻"
    public nonisolated static let verbose: Bool = true

    public static let id = "Terminal"
    public static let navigationId: String = "terminal"
    public static let displayName = String(localized: "Terminal", bundle: .module)
    public static let description = String(localized: "Native interactive terminal powered by SwiftTerm", bundle: .module)
    public static let iconName = "terminal"
    public static var category: PluginCategory { .developerTool }
    public static var order: Int { 90 }
    public nonisolated static let policy: PluginPolicy = .optOut

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = TerminalPlugin()

    // MARK: - Lifecycle

    public nonisolated func onRegister() {}

    public nonisolated func onEnable() {}

    public nonisolated func onDisable() {
        Task { @MainActor in
            TerminalTabsViewModel.shared.closeAllSessions()
        }
    }

    @MainActor
    public func configureRuntime(context: PluginRuntimeContext) {
        TerminalPluginBridge.editorThemeIdProvider = {
            context.editorThemeId()
        }
    }

    // MARK: - UI (Sidebar Panel)

    @MainActor
    public func addPosterViews() -> [AnyView] {
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
    public func addViewContainer() -> ViewContainerItem? {
        ViewContainerItem(id: Self.id, title: Self.displayName, icon: Self.iconName) {
            AnyView(TerminalMainView())
        }
    }
}
