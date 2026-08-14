import KernelLumi
import LumiUI
import SwiftUI

/// 侧边栏标签栏视图
///
/// 显示当前容器可用的 rail tabs，用户点击切换活跃 tab。
///
/// 当容器拥有专属 rail tab（`visibility == .viewContainer(id: 当前容器)`）时，
/// 只展示这些专属 tab（见 `filteredRailTabs`），不再混入 `.always` 等全局 tab；
/// 否则展示全部可用 tab。
///
/// 不订阅 workspace 服务的 `objectWillChange`，
/// 改为「快照 + 事件刷新」：init 读一次初值，监听三个事件：
/// - `.workspaceContributionsDidChange`：rail tab 清单变更；
/// - `.activeViewContainerIDDidChange`：切换容器后过滤条件（supportsProject / chatVisibility）变化；
/// - `.activeRailTabIDDidChange`：其他路径（如恢复、命令）修改选中 tab 时同步快照。
struct RailTabBarView: View {
    let kernel: KernelLumi

    @State private var allRailTabs: [PanelRailTabItem] = []
    @State private var viewContainerID: String
    @State private var activeRailTabID: String
    @State private var containerSnapshot: ContainerSnapshot

    @LumiTheme private var theme

    init(kernel: KernelLumi) {
        self.kernel = kernel
        let workspace = kernel.workspace
        _allRailTabs = State(initialValue: workspace?.allPanelRailTabItems ?? [])
        let containerID = workspace?.activeViewContainerID ?? ""
        _viewContainerID = State(initialValue: containerID)
        _activeRailTabID = State(initialValue: workspace?.activeRailTabID(for: containerID) ?? "")
        _containerSnapshot = State(initialValue: ContainerSnapshot(workspace: workspace, containerID: containerID))
    }

    @MainActor
    private struct ContainerSnapshot: Equatable {
        let supportsProject: Bool
        let supportsChat: Bool

        init(workspace: (any WorkspaceProviding)?, containerID: String) {
            let container = workspace?.viewContainer(id: containerID)
            self.supportsProject = container?.supportsProject == true
            self.supportsChat = container?.chatVisibility.isSupported == true
        }
    }

    /// 按当前容器条件过滤后的可见 tabs。
    private var tabs: [PanelRailTabItem] {
        filteredRailTabs(
            allRailTabs,
            containerID: viewContainerID,
            supportsProject: containerSnapshot.supportsProject,
            supportsChat: containerSnapshot.supportsChat
        )
    }

    /// 仅当已注册的侧边栏标签多于一个时才显示标签栏。
    private var showsTabBar: Bool {
        tabs.count > 1
    }

    @ViewBuilder
    var body: some View {
        // 事件修饰符挂在 Group 外层：showsTabBar 依赖 tabs，而 tabs 依赖多个快照，
        // 分支首次可能为 false。若把修饰符挂进 if 内，分支不渲染时监听永不绑定，
        // 下一次数据变更后永远无法恢复。Group 恒存在，保证持续监听。
        Group {
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
                                // 写操作后同步本地快照（事件会再发一次，但同步更新可避免首帧闪烁）
                                activeRailTabID = newValue
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
        .onWorkspaceContributionsDidChange { reload() }
        .onActiveViewContainerIDDidChange { newContainerID in
            viewContainerID = newContainerID ?? ""
            containerSnapshot = ContainerSnapshot(workspace: kernel.workspace, containerID: newContainerID ?? "")
            activeRailTabID = kernel.workspace?.activeRailTabID(for: newContainerID ?? "") ?? ""
            ensureValidSelection()
        }
        .onActiveRailTabIDDidChange { newContainerID, newRailTabID in
            guard newContainerID == viewContainerID else { return }
            activeRailTabID = newRailTabID
        }
    }

    private func reload() {
        allRailTabs = kernel.workspace?.allPanelRailTabItems ?? []
    }

    private func ensureValidSelection() {
        guard !tabs.isEmpty else { return }
        if tabs.contains(where: { $0.id == activeRailTabID }) { return }
        let firstID = tabs[0].id
        kernel.workspace?.presentRailTab(id: firstID, for: viewContainerID)
        activeRailTabID = firstID
    }
}
