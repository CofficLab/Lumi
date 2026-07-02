import LumiCoreKit
import LumiUI
import SwiftUI

struct RailView: View {
    @LumiTheme private var theme

    let tabs: [LumiPanelRailTabItem]
    @ObservedObject var layoutState: PanelLayoutState

    private static let minWidth: CGFloat = 200

    private var showsTabBar: Bool {
        tabs.count > 1
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsTabBar {
                RailTabBarView(
                    tabs: tabs,
                    selectedTabID: Binding(
                        get: { layoutState.activeRailTabID },
                        set: { newValue in
                            layoutState.activeRailTabID = newValue
                            layoutState.persistActiveRailTabID()
                        }
                    )
                )
            }
            RailContentView(
                tabs: tabs,
                activeTabID: layoutState.activeRailTabID
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: Self.minWidth, maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.surface)
        .borderTrailing()
        .onAppear {
            ensureValidSelection()
        }
        .onChange(of: tabs.map(\.id)) { _, _ in
            ensureValidSelection()
        }
    }

    private func ensureValidSelection() {
        guard !tabs.isEmpty else { return }

        if tabs.contains(where: { $0.id == layoutState.activeRailTabID }) {
            return
        }

        layoutState.activeRailTabID = tabs[0].id
        layoutState.persistActiveRailTabID()
    }
}
