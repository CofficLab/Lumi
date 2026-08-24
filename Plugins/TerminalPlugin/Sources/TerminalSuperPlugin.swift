import Combine
import KernelCore
import LumiUI
import ProviderActivityBar
import ProviderContentView
import ProviderDocsView
import ProviderProject
import ProviderWorkspace
import SwiftUI
import TerminalCoreKit

/// KernelCore entry point for the legacy terminal workspace.
///
/// It keeps the established terminal session model and project-directory
/// behavior while using V2 activity/content/workspace contributions.
@MainActor
public final class TerminalSuperPlugin: SuperPlugin {
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

    public func onBoot(kernel: KernelCoreContainer) throws {
        TerminalPluginBridge.editorThemeIdProvider = {
            LumiUIThemeRegistry.shared.resolvedEditorThemeId(
                colorScheme: SystemAppearanceResolver.effectiveColorScheme
            ) ?? "xcode-dark"
        }

        let content = kernel.resolveProvider((any ContentViewProviding).self)
        let workspace = kernel.resolveProvider((any WorkspaceProviding).self)
        let project = kernel.resolveProvider((any ProjectProviding).self)
        workspace?.registerContainer(.init(
            id: id,
            title: metadata.name,
            systemImage: "terminal",
            order: order,
            supportsProject: true,
            railVisibility: .unsupported,
            chatVisibility: .unsupported,
            panelHeaderVisibility: .unsupported,
            panelBodyVisibility: .unsupported,
            panelBottomVisibility: .unsupported
        ), ownerPluginID: id)
        kernel.resolveProvider((any ActivityBarProviding).self)?.addItems([
            ActivityBarItem(
                id: "\(id).entry",
                title: metadata.name,
                systemImage: "terminal",
                order: order,
                ownerPluginID: id
            ) { activeID in
                guard activeID == "\(self.id).entry" else { return }
                content?.setContentView(AnyView(TerminalV2MainView(project: project)))
                workspace?.activateContainer(id: self.id)
            },
        ])
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: metadata.name) { TerminalAboutView() })
            docs.addManual(DocsEntry(id: id, name: metadata.name) { TerminalManualView() })
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        TerminalTabsViewModel.shared.closeAllSessions()
        TerminalTabsViewModel.bottomPanel.closeAllSessions()
        let activityBar = kernel.resolveProvider((any ActivityBarProviding).self)
        activityBar?.removeItems(ids: ["\(id).entry"])
        if activityBar == nil || activityBar?.activeItemID == nil {
            kernel.resolveProvider((any ContentViewProviding).self)?.setContentView(nil)
        }
        kernel.resolveProvider((any WorkspaceProviding).self)?.unregisterContainers(ownerPluginID: id)
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
    private var cancellable: AnyCancellable?
    private let project: (any ProjectProviding)?

    init(project: (any ProjectProviding)?) {
        self.project = project
        self.currentPath = project?.currentProject?.path
        cancellable = project?.objectWillChange.sink { [weak self] _ in
            self?.currentPath = self?.project?.currentProject?.path
        }
    }
}
