import LumiKernel
import LumiUI
import SwiftUI

// MARK: - Rail Tab Bar View

/// 侧边栏标签栏视图
///
/// 只接收 kernel，所需数据（tabs、当前选中项）由视图自身从内核读取，
/// 选中变更也通过内核回写。
struct RailTabBarView: View {
    @ObservedObject var kernel: LumiKernel

    @LumiTheme private var theme

    private var tabs: [PanelRailTabItem] {
        guard let workspace = kernel.workspace else { return [] }
        let containerID = workspace.activeViewContainerID ?? ""
        return workspace.allPanelRailTabItems.filter { $0.visibility.isVisible(in: containerID) }
    }

    private var viewContainerID: String {
        kernel.workspace?.activeViewContainerID ?? ""
    }

    private var activeRailTabID: String {
        kernel.workspace?.activeRailTabID(for: viewContainerID) ?? ""
    }

    /// 仅当已注册的侧边栏标签多于一个时才显示标签栏。
    private var showsTabBar: Bool {
        tabs.count > 1
    }

    @ViewBuilder
    var body: some View {
        if showsTabBar {
            AppToolbarContainer(
                height: 40,
                backgroundStyle: .panel,
                padding: EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
            ) {
                AppTabBar(
                    tabs: tabs.map { AppTabBar.Tab(title: $0.title, icon: $0.systemImage, id: $0.id) },
                    selectedTab: Binding(
                        get: { activeRailTabID },
                        set: { newValue in
                            kernel.workspace?.presentRailTab(id: newValue, for: viewContainerID)
                        }
                    ),
                    showText: false
                )
            }
            .borderBottom()
            .shadowMd()
            .onAppear {
                ensureValidSelection()
            }
            .onChange(of: tabs.map(\.id)) { _, _ in
                ensureValidSelection()
            }
        }
    }

    private func ensureValidSelection() {
        guard !tabs.isEmpty else { return }
        if tabs.contains(where: { $0.id == activeRailTabID }) { return }
        kernel.workspace?.presentRailTab(id: tabs[0].id, for: viewContainerID)
    }
}
