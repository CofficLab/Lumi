import LumiKernel
import LumiUI
import SwiftUI

// MARK: - Rail Tab Bar View

/// 侧边栏标签栏视图
///
/// 只接收 kernel，所需数据（tabs、当前选中项）由视图自身从内核读取，
/// 选中变更也通过内核回写。
struct RailTabBarView: View {
    let kernel: LumiKernel

    // 只订阅 workspace 这一个 service：本视图不挂在 kernel 全局总线上，
    // project/conversations/settings 等无关服务变更不会触发这里刷新。
    // 在 init 阶段同步绑定：本视图是条件 body（if showsTabBar），异步 .task 绑定会导致
    // 首次 body 求值时 service 为 nil → 条件为 false → 时序竞争。
    @StateObject private var workspaceBox: ObservableWorkspaceBox

    @LumiTheme private var theme

    init(kernel: LumiKernel) {
        self.kernel = kernel
        _workspaceBox = StateObject(wrappedValue: ObservableWorkspaceBox(service: kernel.workspace))
    }

    private var tabs: [PanelRailTabItem] {
        guard let workspace = workspaceBox.service else { return [] }
        let containerID = workspace.activeViewContainerID ?? ""
        let container = workspace.currentViewContainer
        let supportsProject = container?.supportsProject == true
        let supportsChat = container?.chatVisibility.isSupported == true
        return workspace.allPanelRailTabItems.filter {
            $0.visibility.isVisible(in: containerID)
                && (!$0.requiresProjectSupport || supportsProject)
                && (!$0.requiresChatSupport || supportsChat)
        }
    }

    private var viewContainerID: String {
        workspaceBox.service?.activeViewContainerID ?? ""
    }

    private var activeRailTabID: String {
        workspaceBox.service?.activeRailTabID(for: viewContainerID) ?? ""
    }

    /// 仅当已注册的侧边栏标签多于一个时才显示标签栏。
    private var showsTabBar: Bool {
        tabs.count > 1
    }

    @ViewBuilder
    var body: some View {
        // 用 Group 包裹条件分支，并把 .task 挂在 Group 上：
        // showsTabBar 依赖 tabs，而 tabs 依赖 workspaceBox.service（绑定前为 nil），分支首次必为 false。
        // 若把 .task 挂进 if 内，分支不渲染时 bind 永不执行（死锁）。Group 恒存在，保证绑定。
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
                                workspaceBox.service?.presentRailTab(id: newValue, for: viewContainerID)
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
    }

    private func ensureValidSelection() {
        guard !tabs.isEmpty else { return }
        if tabs.contains(where: { $0.id == activeRailTabID }) { return }
        workspaceBox.service?.presentRailTab(id: tabs[0].id, for: viewContainerID)
    }
}
