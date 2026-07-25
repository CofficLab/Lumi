import LumiKernel
import LumiUI
import SwiftUI

/// 底部面板视图
///
/// 只接收 kernel，所需数据（底部标签、当前激活的 view container、
/// 标签选中态）由视图自身从内核读取。
struct PanelBottomView: View {
    @ObservedObject var kernel: LumiKernel

    @LumiTheme private var theme

    private var tabs: [PanelBottomTabItem] {
        kernel.sharedUI?.allPanelBottomTabItems ?? []
    }

    private var viewContainerID: String {
        kernel.layoutManager?.activeViewContainerID ?? ""
    }

    private var container: ViewContainerItem? {
        guard !viewContainerID.isEmpty else { return nil }
        return kernel.layoutManager?.allViewContainers.first { $0.id == viewContainerID }
    }

    private var isBottomPanelVisible: Bool {
        container?.isPanelBottomVisible
            ?? kernel.layoutManager?.bottomPanelVisible
            ?? true
    }

    private var layoutState: LayoutState {
        kernel.layoutManager?.layoutState ?? LayoutState()
    }

    var body: some View {
        Group {
            if isBottomPanelVisible {
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
            AppEmptyState(
                icon: "square.split.2x1",
                title: "No panels"
            )
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
