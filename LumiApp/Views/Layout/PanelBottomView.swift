import LayoutPlugin
import LumiCoreKit
import LumiUI
import SwiftUI

struct PanelBottomView: View {
    @LumiTheme private var theme

    let tabs: [LumiPanelBottomTabItem]
    @ObservedObject var layoutState: PanelLayoutState
    let viewContainerID: String

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            AppDivider()
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minHeight: SplitViewHeightPersistence.minimumHeight)
        .background(theme.surface)
        .background {
            SplitViewHeightPersistence(
                storageKey: LayoutStorageKey.bottomPanelHeight(viewContainerID: viewContainerID)
            )
            .id(layoutState.bottomPanelFocusGeneration)
        }
        .onAppear {
            ensureValidSelection()
        }
        .onChange(of: tabs.map(\.id)) { _, _ in
            ensureValidSelection()
        }
    }

    private var tabBar: some View {
        AppTabBar(
            tabs: tabs.map { AppTabBar.Tab(title: $0.title, icon: $0.systemImage, id: $0.id) },
            selectedTab: Binding(
                get: { layoutState.activeBottomTabID },
                set: { layoutState.activeBottomTabID = $0 }
            )
        )
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .background(theme.surface.opacity(0.85))
    }

    @ViewBuilder
    private var tabContent: some View {
        if let tab = tabs.first(where: { $0.id == layoutState.activeBottomTabID }) ?? tabs.first {
            tab.makeView()
                .id(tab.id)
        } else {
            Color.clear
        }
    }

    private func ensureValidSelection() {
        guard !tabs.isEmpty else { return }

        if tabs.contains(where: { $0.id == layoutState.activeBottomTabID }) {
            return
        }

        layoutState.activeBottomTabID = tabs[0].id
    }
}
