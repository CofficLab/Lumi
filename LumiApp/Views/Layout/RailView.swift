import LumiCoreKit
import LumiUI
import SwiftUI

struct RailView: View {
    @LumiTheme private var theme

    /// Set to `false` to hide the rail edge border.
    static let showsBorder = true

    let tabs: [LumiPanelRailTabItem]
    @ObservedObject var layoutState: PanelLayoutState

    private static let minWidth: CGFloat = 200

    private var showsTabBar: Bool {
        tabs.count > 1
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsTabBar {
                railTabBar
            }
            railContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: Self.minWidth, maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.surface)
        .overlay(alignment: .trailing) {
            if Self.showsBorder {
                AppDivider(.vertical)
            }
        }
        .onAppear {
            ensureValidSelection()
        }
        .onChange(of: tabs.map(\.id)) { _, _ in
            ensureValidSelection()
        }
    }

    private var railTabBar: some View {
        AppToolbarContainer(
            height: 40,
            bottomShadowLevel: .md,
            backgroundStyle: .panel,
            padding: EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
        ) {
            AppTabBar(
                tabs: tabs.map { AppTabBar.Tab(title: $0.title, icon: $0.systemImage, id: $0.id) },
                selectedTab: Binding(
                    get: { layoutState.activeRailTabID },
                    set: { newValue in
                        layoutState.activeRailTabID = newValue
                        layoutState.persistActiveRailTabID()
                    }
                ),
                showText: false
            )
        }
    }

    @ViewBuilder
    private var railContent: some View {
        if let tab = tabs.first(where: { $0.id == layoutState.activeRailTabID }) ?? tabs.first {
            tab.makeView()
                .id(tab.id)
        } else {
            Color.clear
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
