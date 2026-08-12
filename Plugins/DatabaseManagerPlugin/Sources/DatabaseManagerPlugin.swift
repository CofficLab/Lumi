import LumiKernel
import LumiUI
import os
import SuperLogKit
import SwiftUI

@MainActor
public final class DatabaseManagerPlugin: LumiPlugin, SuperLog {
    public nonisolated static let emoji = "🗄️"
    public nonisolated static let verbose = false
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "DatabaseManagerPlugin")

    public let id = "com.coffic.lumi.plugin.database-manager"
    public var name: String {
        LumiPluginLocalization.string("Database", bundle: .module)
    }

    public let order = 750
    public let policy: LumiPluginPolicy = .optIn
    public let stage: LumiPluginStage = .beta
    public let category: LumiPluginCategory = .development

    public init() {}

    /// 插件级唯一的 DatabaseViewModel 实例。
    /// 通过 `viewContainers` 和 `titleToolbarItems` 同时注入，
    /// 让 `DatabaseMainView`（面板）与 `DatabaseToolbarButton`（工具栏 popover）
    /// 共享同一份连接/选中状态，避免"在 popover 选了连接但面板没同步"的问题。
    private let sharedViewModel = DatabaseViewModel()

    public func onBoot(kernel: LumiKernel) async throws {}

    public func onReady(kernel: LumiKernel) async throws {}

    public func agentTools(kernel: LumiKernel) -> [any LumiAgentTool] {
        [
            DatabaseListConnectionsTool(),
            DatabaseDescribeSchemaTool(),
            DatabaseReadonlyQueryTool(),
            DatabaseSampleTableTool(),
        ]
    }

    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] {
        [
            ViewContainerItem(
                id: "database-manager",
                title: LumiPluginLocalization.string("Database", bundle: .module),
                systemImage: "cylinder.split.1x2",
                railVisibility: .alwaysVisible,
                chatVisibility: .unsupported,
                panelHeaderVisibility: .unsupported,
                panelBodyVisibility: .alwaysVisible,
                panelBottomVisibility: .unsupported
            ) {
                AnyView(DatabaseWorkspaceView(viewModel: self.sharedViewModel))
            },
        ]
    }

    public func pluginAboutView(kernel: LumiKernel) -> AnyView? {
        AnyView(AboutView())
    }

    // MARK: - LumiPlugin stubs

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] {
        [
            LumiTitleToolbarItem(
                id: "\(id).title",
                title: name,
                placement: .center,
                order: 0
            ) {
                Text(self.name)
                    .font(.system(size: 13, weight: .semibold))
            },
            LumiTitleToolbarItem(
                id: "\(id).toolbar-button",
                title: LumiPluginLocalization.string("Database Connections", bundle: .module),
                placement: .trailing,
                order: 500
            ) {
                DatabaseToolbarButton(kernel: kernel, containerID: "database-manager", viewModel: self.sharedViewModel)
            },
        ]
    }

    public func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] {
        [
            PanelRailTabItem(
                id: "database-manager.sidebar",
                title: LumiPluginLocalization.string("Database", bundle: .module),
                systemImage: "cylinder.split.1x2",
                visibility: .viewContainer(id: "database-manager")
            ) {
                SidebarView(viewModel: self.sharedViewModel)
            },
        ]
    }
    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] { [] }
    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    public func llmProviderSettingsItems(kernel: LumiKernel) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: LumiKernel) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: LumiKernel) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: LumiKernel) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: LumiKernel) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: LumiKernel, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}

    // MARK: - External File Opening

    /// SQLite 可识别的文件扩展名（与 Info.plist 中 `com.coffic.lumi.sqlite` 的声明保持一致）。
    private static let sqliteExtensions: Set<String> = ["sqlite", "sqlite3", "db"]

    /// 接管外部打开的 SQLite 数据库文件：
    /// 1. 记录/复用该文件的连接配置；
    /// 2. 激活 `database-manager` 视图容器；
    /// 3. 自动建立连接。
    public func openFile(kernel: LumiKernel, url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        guard Self.sqliteExtensions.contains(ext) else { return false }

        let path = url.path
        Self.logger.info("\(Self.t)Opening SQLite database file: \(path)")

        let config: DatabaseConfig
        if let existing = sharedViewModel.configs.first(where: {
            $0.type == .sqlite && $0.database == path
        }) {
            config = existing
        } else {
            config = DatabaseConfig(
                name: url.deletingPathExtension().lastPathComponent,
                type: .sqlite,
                database: path
            )
            sharedViewModel.addConfig(config)
        }

        kernel.workspace?.activateContainer(id: "database-manager")
        Task { @MainActor in
            await sharedViewModel.connect(config: config)
        }
        return true
    }
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
}
