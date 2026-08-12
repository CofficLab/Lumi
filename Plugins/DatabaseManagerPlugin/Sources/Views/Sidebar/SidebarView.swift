import SwiftUI
import LumiUI
import LumiKernel

/// Database 侧边栏：可切换的「数据浏览（Tables / Keys）」与「连接管理」面板。
///
/// 由 ``DatabaseManagerPlugin`` 注册为 RailView 的 `PanelRailTabItem`，
/// 仅在 database-manager ViewContainer 中可见。
///
/// - 顶部 ``DatabaseSidebarHeaderBar`` 提供标题、Reload、Add 与切换按钮；
/// - ``DatabaseViewModel.sidebarMode`` 控制当前展示的面板；
/// - 两种面板通过 3D 翻转动画（沿 Y 轴 90°）相互切换，类似翻牌效果；
/// - 连接列表中点击某个连接会自动连接并翻牌回数据浏览面板（常见模式：
///   选完连接直接进入数据浏览，避免多一次点击）；
/// - 自动重连逻辑（``DatabaseViewModel.autoConnectIfNeeded``）首次进入 UI 时触发一次。
public struct SidebarView: View {
    @ObservedObject var viewModel: DatabaseViewModel

    public init(viewModel: DatabaseViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        let showingConnections = viewModel.sidebarMode == .connections
        ZStack {
            // 数据浏览面板：Tables（SQLite）或 Keys（Redis）
            dataBrowser
                .opacity(showingConnections ? 0 : 1)
                .rotation3DEffect(
                    .degrees(showingConnections ? -90 : 0),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: .center,
                    perspective: 0.6
                )
                .allowsHitTesting(!showingConnections)
                .accessibilityHidden(showingConnections)

            // 连接管理面板
            ConnectionsListView(
                viewModel: viewModel,
                onToggleMode: { toggleMode() }
            )
            .opacity(showingConnections ? 1 : 0)
            .rotation3DEffect(
                .degrees(showingConnections ? 0 : 90),
                axis: (x: 0, y: 1, z: 0),
                anchor: .center,
                perspective: 0.6
            )
            .allowsHitTesting(showingConnections)
            .accessibilityHidden(!showingConnections)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.easeInOut(duration: 0.32), value: viewModel.sidebarMode)
        .onChange(of: viewModel.isConnected) { _, isConnected in
            // 连接成功 → 自动翻回数据浏览，让用户直接看表
            if isConnected, viewModel.sidebarMode == .connections {
                withAnimation(.easeInOut(duration: 0.32)) {
                    viewModel.sidebarMode = .browser
                }
            }
        }
        .onAppear {
            viewModel.autoConnectIfNeeded()
        }
    }

    // MARK: - Mode Toggle

    private func toggleMode() {
        withAnimation(.easeInOut(duration: 0.32)) {
            viewModel.sidebarMode = viewModel.sidebarMode == .connections ? .browser : .connections
        }
    }

    // MARK: - Data Browser

    @ViewBuilder
    private var dataBrowser: some View {
        VStack(spacing: 0) {
            switch viewModel.selectedConfig?.type {
            case .redis:
                keysBrowser
            case .sqlite, .mysql, .postgresql:
                DatabaseObjectTreeView(viewModel: viewModel, onToggleMode: { toggleMode() })
            case nil:
                emptyHint
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var keysBrowser: some View {
        VStack(spacing: 0) {
            DatabaseSidebarHeaderBar(
                title: LumiPluginLocalization.string("Keys", bundle: .module),
                systemImage: "key",
                onLoad: { Task { await viewModel.loadRedisKeys() } },
                onToggleMode: { toggleMode() },
                toggleMode: viewModel.sidebarMode
            )

            if viewModel.redisKeys.isEmpty {
                SidebarEmptyView(
                    systemImage: "key",
                    title: LumiPluginLocalization.string("No keys", bundle: .module),
                    description: LumiPluginLocalization.string("Click Reload to refresh the key list.", bundle: .module)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(viewModel.redisKeys, id: \.self) { key in
                            DatabaseKeyRow(key: key) {
                                Task { await viewModel.openRedisKey(key) }
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.hidden)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 未连接到任何数据库时的占位视图。
    /// 提示用户通过顶部切换按钮进入 Connections 面板添加/选择连接。
    private var emptyHint: some View {
        VStack(spacing: 0) {
            DatabaseSidebarHeaderBar(
                title: LumiPluginLocalization.string("Database", bundle: .module),
                systemImage: "cylinder.split.1x2",
                onToggleMode: { toggleMode() },
                toggleMode: viewModel.sidebarMode
            )
            SidebarEmptyView(
                systemImage: "cylinder.split.1x2",
                title: LumiPluginLocalization.string("No database connected", bundle: .module),
                description: LumiPluginLocalization.string("Switch to Connections above to add or pick a database.", bundle: .module)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#if DEBUG
#Preview("Sidebar") {
    SidebarView(viewModel: DatabaseViewModel())
        .frame(width: 260, height: 400)
}
#endif