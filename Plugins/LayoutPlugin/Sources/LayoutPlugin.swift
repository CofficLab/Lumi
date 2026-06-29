import LumiCoreKit
import SwiftUI

/// Persists the active view container across launches.
public enum LayoutPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .general
    public static let iconName = "sidebar.left"

    @MainActor
    private static var didRestorePersistedState = false

    /// Restores persisted layout state before the main window renders.
    @MainActor
    public static func restorePersistedStateIfNeeded() {
        guard !didRestorePersistedState else { return }
        didRestorePersistedState = true

        let layoutState = LumiLayoutStateStore.shared
        if let savedID = LayoutPluginLocalStore.shared.loadActiveViewContainerID() {
            layoutState.activeViewContainerID = savedID
        }
        if let savedVisible = LayoutPluginLocalStore.shared.loadRightSidebarVisible() {
            layoutState.chatSectionVisible = savedVisible
        }
        if let savedBottomVisible = LayoutPluginLocalStore.shared.loadBottomPanelVisible() {
            layoutState.bottomPanelVisible = savedBottomVisible
        }
    }

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.layout",
        displayName: LumiPluginLocalization.string("Layout Persistence", bundle: .module),
        description: LumiPluginLocalization.string("Persist and restore layout state across app launches", bundle: .module),
        order: 99
    )

    @MainActor
    public static func rootOverlays(context: LumiPluginContext) -> [LumiRootOverlayItem] {
        [
            LumiRootOverlayItem(id: info.id, order: info.order) { content in
                LayoutPersistenceAnchor(content: content)
            }
        ]
    }

    @MainActor
    public static func titleToolbarItems(context: LumiPluginContext) -> [LumiTitleToolbarItem] {
        [
            LumiTitleToolbarItem(
                id: "\(info.id).layout-menu",
                title: LumiPluginLocalization.string("Layout", bundle: .module),
                placement: .trailing
            ) {
                LayoutMenuButton(
                    layoutContext: LayoutControlContext(
                        chatSectionVisible: Binding(
                            get: { LumiLayoutStateStore.shared.chatSectionVisible },
                            set: { LumiLayoutStateStore.shared.chatSectionVisible = $0 }
                        ),
                        bottomPanelVisible: Binding(
                            get: { LumiLayoutStateStore.shared.bottomPanelVisible },
                            set: { LumiLayoutStateStore.shared.bottomPanelVisible = $0 }
                        )
                    )
                )
            }
        ]
    }
}

private struct LayoutPersistenceAnchor: View {
    let content: AnyView
    @ObservedObject private var layoutState = LumiLayoutStateStore.shared

    var body: some View {
        content
            .onChange(of: layoutState.activeViewContainerID) { _, newValue in
                LayoutPluginLocalStore.shared.saveActiveViewContainerID(newValue)
            }
            .onChange(of: layoutState.chatSectionVisible) { _, newValue in
                LayoutPluginLocalStore.shared.saveRightSidebarVisible(newValue)
            }
            .onChange(of: layoutState.bottomPanelVisible) { _, newValue in
                LayoutPluginLocalStore.shared.saveBottomPanelVisible(newValue)
            }
    }
}
