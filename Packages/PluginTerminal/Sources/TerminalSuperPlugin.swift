import Combine
import KernelCore
import LumiUI
import ProviderActivityBar
import ProviderChatSection
import ProviderContentView
import ProviderDocsView
import ProviderProject
import ProviderRailView
import ProviderToolbar
import ProviderRootView
import SwiftUI
import KitTerminalCore
import KitSuperLog
import os

/// KernelCore entry point for the legacy terminal workspace.
///
/// It keeps the established terminal session model and project-directory
/// behavior while using V2 activity/content contributions.
@MainActor
public final class TerminalSuperPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.terminal", category: "Terminal")
    public let id = "com.coffic.lumi.plugin.terminal"
    public let order = 279
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.terminal",
        name: LumiPluginLocalization.string("Terminal", bundle: .module),
        description: LumiPluginLocalization.string("Integrated terminal sessions for the current project.", bundle: .module),
        category: .editor,
        stage: .preview,
        policy: .disabledByDefault
    )
    private let projectObserver = TerminalV2ProjectObserver(project: nil)

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
        kernel.resolveProvider((any ActivityBarProviding).self)?.addItems([
            ActivityBarItem(
                id: "\(id).entry",
                title: metadata.name,
                systemImage: "terminal",
                order: order,
                ownerPluginID: id
            ) { state in
                if state == .activated {
                    toolbar?.setVisibleCategories([.global, .project])
                    chat?.setVisible(false)
                    rootView?.setRailView(nil)
                    rootView?.setContentHeaderViewHidden(true)
                    content?.setContentView(AnyView(TerminalV2MainView(observer: terminalProjectObserver)))
                } else {
                    toolbar?.setVisibleCategories(Set(ToolbarItemCategory.allCases))
                    chat?.setVisible(true)
                    rootView?.setRailView(railView?.makeRailView())
                    rootView?.setRailViewVisible(railView?.hasVisibleTabs ?? false)
                    rootView?.setContentHeaderViewHidden(false)
                }
            },
        ])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        projectObserver.cancel()
        TerminalTabsViewModel.shared.closeAllSessions()
        TerminalTabsViewModel.bottomPanel.closeAllSessions()
        let activityBar = kernel.resolveProvider((any ActivityBarProviding).self)
        let wasActive = activityBar?.activeItemID == "\(id).entry"
        activityBar?.removeItems(ids: ["\(id).entry"])
        if wasActive {
            kernel.resolveProvider((any ChatSectionProviding).self)?.setVisible(true)
            let rootView = kernel.resolveProvider((any RootViewProviding).self)
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
