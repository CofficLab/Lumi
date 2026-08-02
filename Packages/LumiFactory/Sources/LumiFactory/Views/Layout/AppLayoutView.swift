import LumiKernel
import LumiUI
import SwiftUI

/// 应用主布局
struct AppLayoutView: View {
    @LumiTheme private var theme
    @ObservedObject var kernel: LumiKernel
    private let layoutManager: (any WorkspaceProviding)?

    @State private var isRailVisible: Bool = true
    @State private var isChatVisible: Bool = true

    init(kernel: LumiKernel) {
        self.kernel = kernel
        self.layoutManager = kernel.workspace
    }

    var body: some View {
        if let layoutManager {
            mainLayout(layoutManager)
        } else {
            ErrorView(error: LumiKernelError.serviceNotAvailable(service: "LayoutManager"))
        }
    }

    // MARK: - Main Layout

    @ViewBuilder
    private func mainLayout(_ layoutManager: any WorkspaceProviding) -> some View {
        VStack(spacing: 0) {
            AppTitleToolbar(kernel: kernel)
            AppDivider()

            HStack(spacing: 0) {
                ActivityBar(kernel: kernel)
                    .frame(maxHeight: .infinity)
                AppDivider(.vertical)

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

            AppDivider()
            StatusBar(kernel: kernel)
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
        if showRail(for: layoutManager) {
            HSplitView {
                RailView(kernel: kernel)
                    .frame(minWidth: 180, idealWidth: 240, maxWidth: 400)
                    // 必须挂在 HSplitView 左侧 pane，组件会直接识别原生可拖拽 divider。
                    .appSplitDivider(.trailing)
                mainSplitContent(layoutManager)
            }
        } else {
            mainSplitContent(layoutManager)
        }
    }

    @ViewBuilder
    private func mainSplitContent(_ layoutManager: any WorkspaceProviding) -> some View {
        if showChat(for: layoutManager) {
            HSplitView {
                PanelView(kernel: kernel, layoutManager: layoutManager)
                    .frame(minWidth: 280, maxWidth: .infinity)
                    .appSplitDivider(.trailing)
                ChatView(kernel: kernel)
                    .frame(minWidth: 280, idealWidth: 320, maxWidth: .infinity)
            }
        } else {
            PanelView(kernel: kernel, layoutManager: layoutManager)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
