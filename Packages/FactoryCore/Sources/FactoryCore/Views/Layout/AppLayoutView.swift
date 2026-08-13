import KernelLumi
import LumiUI
import SwiftUI

/// Controls whether native split-divider changes are forwarded to the kernel.
/// Keep disabled while comparing the UI-only behavior with kernel synchronization.
enum LayoutDividerSyncConfiguration {
    static let syncChangesToKernel = true
}

/// 应用主布局
struct AppLayoutView: View {
    @LumiTheme private var theme
    @ObservedObject var kernel: KernelLumi
    private let layoutManager: (any WorkspaceProviding)?
    private let showsStatusBar: Bool
    private let showsActivityBar: Bool

    @State private var isRailVisible: Bool = true
    @State private var isChatVisible: Bool = true
    @State private var activityBarContainerCount: Int
    @State private var statusBarItemCount: Int

    init(
        kernel: KernelLumi,
        showsStatusBar: Bool = true,
        showsActivityBar: Bool = true
    ) {
        self.kernel = kernel
        self.layoutManager = kernel.workspace
        self.showsStatusBar = showsStatusBar
        self.showsActivityBar = showsActivityBar
        _activityBarContainerCount = State(
            initialValue: kernel.workspace?.allViewContainers.count ?? 0
        )
        _statusBarItemCount = State(
            initialValue: kernel.workspace?.allStatusBarItems.count ?? 0
        )
    }

    var body: some View {
        if let layoutManager {
            mainLayout(layoutManager)
        } else {
            ErrorView(error: KernelLumiError.serviceNotAvailable(service: "LayoutManager"))
        }
    }

    // MARK: - Main Layout

    @ViewBuilder
    private func mainLayout(_ layoutManager: any WorkspaceProviding) -> some View {
        VStack(spacing: 0) {
            AppTitleToolbar(kernel: kernel)
            AppDivider()

            HStack(spacing: 0) {
                if showsActivityBar, activityBarContainerCount > 1 {
                    ActivityBar(kernel: kernel)
                        .frame(maxHeight: .infinity)
                    AppDivider(.vertical)
                }

                Group {
                    if layoutManager.activeViewContainerID != nil {
                        splitLayout(layoutManager)
                    } else {
                        WelcomeView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 没有任何插件注入状态栏项时，整个状态栏（含分隔线）不显示。
            if showsStatusBar, statusBarItemCount > 0 {
                AppDivider()
                StatusBar(kernel: kernel)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
        .appThemedAppearance()
        .background {
            ThemeWindowAppearanceBridge()
        }
        .environmentObject(AppThemeVM.shared)
        .ignoresSafeArea()
        .onRailVisibleDidChange { visible in
            isRailVisible = visible
        }
        .onChatSectionVisibleDidChange { visible in
            isChatVisible = visible
        }
        .onAppear {
            isRailVisible = layoutManager.isRailVisible
            isChatVisible = layoutManager.isChatVisible
            activityBarContainerCount = layoutManager.allViewContainers.count
            statusBarItemCount = layoutManager.allStatusBarItems.count
        }
        .onWorkspaceContributionsDidChange {
            activityBarContainerCount = layoutManager.allViewContainers.count
            statusBarItemCount = layoutManager.allStatusBarItems.count
        }
    }

    // MARK: - Split Layout

    private func showRail(for layoutManager: any WorkspaceProviding) -> Bool {
        isRailVisible && layoutManager.activeViewContainerID != nil
    }

    private func showChat(for layoutManager: any WorkspaceProviding) -> Bool {
        isChatVisible && layoutManager.activeViewContainerID != nil
    }

    @ViewBuilder
    private func splitLayout(_ layoutManager: any WorkspaceProviding) -> some View {
        let containerID = layoutManager.activeViewContainerID ?? ""
        let railWidth = layoutManager.railDivider(for: containerID, fallback: 240)
        if showRail(for: layoutManager) {
            HSplitView {
                RailView(kernel: kernel)
                    .frame(minWidth: 180, idealWidth: railWidth, maxWidth: 400)
                    // 必须挂在 HSplitView 左侧 pane，组件会直接识别原生可拖拽 divider。
                    .appSplitDivider(.trailing, initialPosition: railWidth) { position in
                        guard LayoutDividerSyncConfiguration.syncChangesToKernel else { return }
                        layoutManager.setRailDivider(position, for: containerID)
                    }
                mainSplitContent(layoutManager)
            }
            .id("host.rail.\(containerID)")
        } else {
            mainSplitContent(layoutManager)
        }
    }

    @ViewBuilder
    private func mainSplitContent(_ layoutManager: any WorkspaceProviding) -> some View {
        let containerID = layoutManager.activeViewContainerID ?? ""
        let panelWidth = layoutManager.chatSectionDivider(
            for: containerID,
            layout: .narrow,
            fallback: 320
        )
        if showChat(for: layoutManager) {
            HSplitView {
                PanelView(kernel: kernel, layoutManager: layoutManager)
                    .frame(minWidth: 280, idealWidth: panelWidth, maxWidth: .infinity)
                    .appSplitDivider(.trailing, initialPosition: panelWidth) { position in
                        guard LayoutDividerSyncConfiguration.syncChangesToKernel else { return }
                        layoutManager.setChatSectionDivider(
                            position,
                            for: containerID,
                            layout: .narrow
                        )
                    }
                ChatView(kernel: kernel)
                    .frame(minWidth: 280, idealWidth: 320, maxWidth: .infinity)
            }
            .id("host.chat.\(containerID)")
        } else {
            PanelView(kernel: kernel, layoutManager: layoutManager)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
