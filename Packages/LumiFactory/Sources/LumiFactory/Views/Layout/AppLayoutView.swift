import LumiKernel
import LumiUI
import SwiftUI

/// 应用主布局
struct AppLayoutView: View {
    @LumiTheme private var theme
    @ObservedObject var kernel: LumiKernel

    @State private var isRailVisible: Bool = true
    @State private var isContentVisible: Bool = true
    @State private var isChatVisible: Bool = true

    init(kernel: LumiKernel) {
        self.kernel = kernel
    }

    var body: some View {
        if kernel.layoutManager == nil {
            ErrorView(error: LumiKernelError.serviceNotAvailable(service: "LayoutManager"))
        } else {
            mainLayout
        }
    }

    @ViewBuilder
    private var mainLayout: some View {
        VStack(spacing: 0) {
            AppTitleToolbar(kernel: kernel)
            AppDivider()

            HStack(spacing: 0) {
                ActivityBar(kernel: kernel)
                    .frame(maxHeight: .infinity)
                AppDivider(.vertical)

                Group {
                    if kernel.layoutManager?.layoutState.activeViewContainerID != nil {
                        splitLayout
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
        .environmentObject(AppThemeVM.shared)
        .ignoresSafeArea()
        .onRailVisibleDidChange { visible in
            isRailVisible = visible
        }
        .onChatSectionVisibleDidChange { visible in
            isChatVisible = visible
        }
        .onAppear {
            isRailVisible = kernel.layoutManager?.isRailVisible ?? true
            isContentVisible = kernel.layoutManager?.isContentVisible ?? true
            isChatVisible = kernel.layoutManager?.isChatVisible ?? true
        }
    }

    // MARK: - Split Layout

    private var showRail: Bool {
        isRailVisible && kernel.layoutManager?.layoutState.activeViewContainerID != nil
    }

    private var showChat: Bool {
        isChatVisible && kernel.layoutManager?.layoutState.activeViewContainerID != nil
    }

    private var viewContainerID: String {
        kernel.layoutManager?.layoutState.activeViewContainerID ?? ""
    }

    private var layoutState: LayoutState {
        kernel.layoutManager?.layoutState ?? LayoutState()
    }

    @ViewBuilder
    private var splitLayout: some View {
        if showRail {
            HSplitView {
                RailView(kernel: kernel)
                    .frame(minWidth: 180, idealWidth: 240, maxWidth: 400)
                    .background(
                        SplitViewDividerPersistence.rail(
                            layoutState: layoutState,
                            viewContainerID: viewContainerID
                        )
                    )
                mainSplitContent
            }
        } else {
            mainSplitContent
        }
    }

    @ViewBuilder
    private var mainSplitContent: some View {
        if showChat {
            HSplitView {
                PanelView(kernel: kernel)
                    .frame(minWidth: 280, maxWidth: .infinity)
                ChatView(kernel: kernel)
                    .frame(minWidth: 280, idealWidth: 320, maxWidth: .infinity)
                    .background(
                        SplitViewDividerPersistence.chatSection(
                            layoutState: layoutState,
                            viewContainerID: viewContainerID,
                            layout: .narrow
                        )
                    )
            }
        } else {
            PanelView(kernel: kernel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
