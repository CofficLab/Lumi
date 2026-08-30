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
        name: "Terminal",
        description: "Integrated terminal sessions for the current project.",
        category: .editor,
        stage: .preview,
        policy: .disabledByDefault
    )

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
                    content?.setContentView(AnyView(TerminalV2MainView(project: project)))
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
    @StateObject private var observer: TerminalV2ProjectObserver

    init(project: (any ProjectProviding)?) {
        self._observer = StateObject(wrappedValue: TerminalV2ProjectObserver(project: project))
    }

    var body: some View {
        TerminalMainView(projectPath: observer.currentPath)
    }
}

@MainActor
private final class TerminalV2ProjectObserver: ObservableObject {
    @Published private(set) var currentPath: String?
    private var projectObserver: (any ProjectProvidingObserverHandle)?
    private let project: (any ProjectProviding)?

    init(project: (any ProjectProviding)?) {
        self.project = project
        self.currentPath = project?.currentProject?.path
        projectObserver = project?.addObserver { [weak self] event in
            guard case .currentProjectChanged = event else { return }
            self?.currentPath = self?.project?.currentProject?.path
        }
    }
}
