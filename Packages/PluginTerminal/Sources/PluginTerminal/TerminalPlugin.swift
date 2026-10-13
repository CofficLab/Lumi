import Combine
import KernelCore
import LumiUI
import ProviderActivityBar
import ProviderChatSection
import ProviderContentView
import ProviderDocsView
import ProviderPanelBottom
import ProviderProject
import ProviderRailView
import ProviderToolbar
import ProviderRootView
import SwiftUI
import KitTerminalCore
import LumiLoggingKit
import os

/// KernelCore entry point for the legacy terminal workspace.
///
/// It keeps the established terminal session model and project-directory
/// behavior while using V2 activity/content contributions.
@MainActor
public final class TerminalPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.terminal", category: "Terminal")
    public let id = "com.coffic.lumi.plugin.terminal"
    public let order = 279
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.terminal",
        name: pluginLocalization.string("Terminal"),
        description: pluginLocalization.string("Integrated terminal sessions for the current project."),
        category: .editor,
        stage: .preview,
        policy: .disabledByDefault
    )
    private let projectObserver = TerminalV2ProjectObserver(project: nil)
    /// 底部面板宿主（PanelBottom）引用；缺失时（如 headless ACP）降级为仅 ActivityBar 入口。
    private var panelBottom: (any PanelBottomProviding)?

    public init() {}

    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: metadata.name) { TerminalAboutView() })
            docs.addManual(DocsEntry(id: id, name: metadata.name) { TerminalManualView() })
        }
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        TerminalPluginBridge.editorThemeIdProvider = {
            LumiUIThemeRegistry.shared.resolvedEditorThemeId(
                colorScheme: SystemAppearanceResolver.effectiveColorScheme
            ) ?? "xcode-dark"
        }

        let content = kernel.resolveProvider((any ContentViewProviding).self)
        let chat = kernel.resolveProvider((any ChatSectionProviding).self)
        let project = kernel.resolveProvider((any ProjectProviding).self)
        projectObserver.bind(project: project)
        let terminalProjectObserver = projectObserver
        let railView = kernel.resolveProvider((any RailViewProviding).self)
        let rootView = kernel.resolveProvider((any RootViewProviding).self)
        let toolbar = kernel.resolveProvider((any ToolbarProviding).self)
        rootView?.activateContentFooterHeightProfile(
            ownerID: id,
            recommended: .standard,
            store: nil
        )
        kernel.resolveProvider((any ActivityBarProviding).self)?.addItems([
            ActivityBarItem(
                id: "\(id).entry",
                title: metadata.name,
                systemImage: "terminal",
                order: order,
                ownerPluginID: id,
                // 激活时隐藏 PanelBottom（content footer），不保留底部面板。
                preservesContentFooter: false
            ) { state in
                if state == .activated {
                    toolbar?.setVisibleCategories([.global, .project])
                    chat?.setVisible(false)
                    rootView?.setRailView(nil)
                    rootView?.setContentHeaderViewHidden(true)
                    content?.setContentView(AnyView(TerminalV2MainView(observer: terminalProjectObserver)))
                    // 激活时隐藏底部面板，只保留终端主视图。
                    rootView?.setContentFooterViewHidden(true)
                } else {
                    toolbar?.setVisibleCategories(Set(ToolbarItemCategory.allCases))
                    chat?.setVisible(true)
                    rootView?.setRailView(railView?.makeRailView())
                    rootView?.setRailViewVisible(railView?.hasVisibleTabs ?? false)
                    rootView?.setContentHeaderViewHidden(false)
                }
            },
        ])

        registerPanelBottomTab(kernel: kernel)
    }

    /// 运行时启用：重新注册底部面板入口。
    ///
    /// 启动时被跳过、从未 Boot 的插件走 `onBoot` 完整初始化；曾 Boot 过
    /// 再启用的插件只走本方法。
    public func onEnable(kernel: KernelCoreContainer) async throws {
        registerPanelBottomTab(kernel: kernel)
    }

    /// 运行时禁用：撤回底部面板入口（内核不会代撤 Provider 侧贡献）。
    public func onDisable(kernel: KernelCoreContainer) async throws {
        panelBottom?.removeItems(ownerPluginID: id)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        projectObserver.cancel()
        TerminalTabsViewModel.shared.closeAllSessions()
        TerminalTabsViewModel.bottomPanel.closeAllSessions()
        // 撤回底部面板入口；容器的安装/撤回由 PanelBottom 宿主统一管理。
        panelBottom?.removeItems(ownerPluginID: id)
        panelBottom = nil
        let activityBar = kernel.resolveProvider((any ActivityBarProviding).self)
        let wasActive = activityBar?.activeItemID == "\(id).entry"
        let rootView = kernel.resolveProvider((any RootViewProviding).self)
        rootView?.deactivateContentFooterHeightProfile(ownerID: id)
        activityBar?.removeItems(ids: ["\(id).entry"])
        if wasActive {
            kernel.resolveProvider((any ChatSectionProviding).self)?.setVisible(true)
            let railView = kernel.resolveProvider((any RailViewProviding).self)
            rootView?.setRailView(railView?.makeRailView())
            rootView?.setRailViewVisible(railView?.hasVisibleTabs ?? false)
            rootView?.setContentHeaderViewHidden(false)
        }
        if activityBar == nil || activityBar?.activeItemID == nil {
            kernel.resolveProvider((any ContentViewProviding).self)?.setContentView(nil)
        }
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }

    // MARK: - 私有方法

    /// 注册底部面板 Terminal 入口：与 ActivityBar 全屏终端相互独立的
    /// 底部终端会话（`.bottomPanel` 实例），在编辑器工作区的底部面板以 tab 呈现。
    private func registerPanelBottomTab(kernel: KernelCoreContainer) {
        guard kernel.isProviderRegistered((any PanelBottomProviding).self),
              let panelBottom = kernel.resolveProvider((any PanelBottomProviding).self) else {
            return
        }
        let observer = projectObserver
        self.panelBottom = panelBottom
        panelBottom.addItems([
            PanelBottomItem(
                id: "\(id).terminal",
                title: pluginLocalization.string("Terminal"),
                systemImage: "terminal",
                // tab 权重派生自插件 order，相对顺序由插件目录统一决定。
                order: order,
                ownerPluginID: id
            ) { AnyView(TerminalV2BottomPanelView(observer: observer)) }
        ])
    }
}

@MainActor
private struct TerminalV2MainView: View {
    @ObservedObject private var observer: TerminalV2ProjectObserver

    init(observer: TerminalV2ProjectObserver) {
        self._observer = ObservedObject(wrappedValue: observer)
    }

    var body: some View {
        TerminalMainView(projectPath: observer.currentPath)
    }
}

/// 底部面板中的终端入口视图。
///
/// 与 ViewContainer（`.shared` 实例）使用不同的 ViewModel，
/// 两处的终端会话相互独立。
@MainActor
private struct TerminalV2BottomPanelView: View {
    @ObservedObject private var observer: TerminalV2ProjectObserver

    init(observer: TerminalV2ProjectObserver) {
        self._observer = ObservedObject(wrappedValue: observer)
    }

    var body: some View {
        TerminalMainView(projectPath: observer.currentPath, viewModel: .bottomPanel)
    }
}
