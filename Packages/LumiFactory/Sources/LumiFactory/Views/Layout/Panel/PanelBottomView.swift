import LumiCoreLayout
import LumiKernel
import LumiUI
import SwiftUI

struct PanelBottomView: View {
    @LumiTheme private var theme

    let tabs: [LumiPanelBottomTabItem]
    @ObservedObject var layoutState: LayoutState
    let viewContainerID: String

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            AppDivider()
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minHeight: 80)
        .background(theme.surface)
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
                get: { layoutState.activeBottomTabID(for: viewContainerID) },
                set: { newValue in
                    layoutState.setActiveBottomTabID(newValue, for: viewContainerID)
                }
            )
        )
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .background(theme.surface.opacity(0.85))
    }

    @ViewBuilder
    private var tabContent: some View {
        let selectedID = layoutState.activeBottomTabID(for: viewContainerID)
        if let tab = tabs.first(where: { $0.id == selectedID }) ?? tabs.first {
            tab.makeView()
                .id(tab.id)
        } else {
            Color.clear
        }
    }

    private func ensureValidSelection() {
        guard !tabs.isEmpty else { return }
        let selectedID = layoutState.activeBottomTabID(for: viewContainerID)
        if tabs.contains(where: { $0.id == selectedID }) {
            return
        }
        layoutState.setActiveBottomTabID(tabs[0].id, for: viewContainerID)
    }
}
