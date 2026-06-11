import LumiCoreKit
import SwiftUI

/// Persists the active view container across launches.
public enum LayoutPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .general
    public static let iconName = "sidebar.left"

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
    @State private var hasRestored = false

    var body: some View {
        ZStack {
            content

            Color.clear
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
                .onAppear {
                    restoreIfNeeded()
                }
        }
        .onChange(of: layoutState.activeViewContainerID) { _, newValue in
            guard hasRestored else { return }
            LayoutPluginLocalStore.shared.saveActiveViewContainerID(newValue)
        }
        .onChange(of: layoutState.chatSectionVisible) { _, newValue in
            guard hasRestored else { return }
            LayoutPluginLocalStore.shared.saveRightSidebarVisible(newValue)
        }
    }

    private func restoreIfNeeded() {
        guard !hasRestored else { return }
        hasRestored = true

        if let savedID = LayoutPluginLocalStore.shared.loadActiveViewContainerID() {
            layoutState.activeViewContainerID = savedID
        }
        if let savedVisible = LayoutPluginLocalStore.shared.loadRightSidebarVisible() {
            layoutState.chatSectionVisible = savedVisible
        }
    }
}
