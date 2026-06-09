import LumiCoreKit
import SwiftUI

/// Persists the active view container across launches.
public enum LayoutPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .general
    public static let iconName = "sidebar.left"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.layout",
        displayName: "Layout Persistence",
        description: "Persist and restore layout state across app launches",
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
    }

    private func restoreIfNeeded() {
        guard !hasRestored else { return }
        hasRestored = true

        if let savedID = LayoutPluginLocalStore.shared.loadActiveViewContainerID() {
            layoutState.activeViewContainerID = savedID
        }
    }
}
