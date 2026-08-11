import LumiKernel
import LumiUI
import SwiftUI

/// 底部面板视图
struct PanelBottomView: View {
    private let layoutManager: WorkspaceProviding

    @LumiTheme private var theme
    @State private var selectedTabIDs: [String: String] = [:]
    @State private var isPanelBottomVisible: Bool = true

    init(layoutManager: WorkspaceProviding) {
        self.layoutManager = layoutManager
    }
    
    private var tabs: [PanelBottomTabItem] {
        self.layoutManager.allPanelBottomTabItems
    }

    private var viewContainerID: String {
        layoutManager.activeViewContainerID ?? ""
    }

    /// 当前容器选中的底部 tab（经协议查询，按容器独立记忆 + 持久化）。
    private var selectedTabID: String {
        selectedTabIDs[viewContainerID]
            ?? layoutManager.activeBottomTabID(for: viewContainerID)
    }

    var body: some View {
        Group {
            if isPanelBottomVisible {
                VStack(spacing: 0) {
                    AppTabBar(
                        tabs: tabs.map { AppTabBar.Tab(title: $0.title, icon: $0.systemImage, id: $0.id) },
                        selectedTab: Binding(
                            get: { selectedTabID },
                            set: { newValue in
                                selectedTabIDs[viewContainerID] = newValue
                                layoutManager.presentBottomTab(id: newValue, viewContainerID: viewContainerID)
                            }
                        )
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 8)
                    .background(theme.surface.opacity(0.85))
                    AppDivider()
                    tabContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(minHeight: 80)
                .background(theme.surface)
                .onAppear {
                    isPanelBottomVisible = layoutManager.isPanelBottomVisible
                    syncSelectedTab()
                }
                .onActiveViewContainerIDDidChange { _ in
                    syncSelectedTab()
                }
                .onActiveBottomTabIDDidChange { containerID, tabID in
                    guard containerID == viewContainerID else { return }
                    selectedTabIDs[containerID] = tabID
                }
            }
        }
        .onBottomPanelVisibleDidChange { visible in
            isPanelBottomVisible = visible
        }
    }

    private func syncSelectedTab() {
        guard !viewContainerID.isEmpty else { return }
        selectedTabIDs[viewContainerID] = layoutManager.activeBottomTabID(for: viewContainerID)
    }

    @ViewBuilder
    private var tabContent: some View {
        let selectedID = selectedTabID
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
}
