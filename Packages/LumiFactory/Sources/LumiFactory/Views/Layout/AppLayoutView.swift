import LumiKernel
import LumiUI
import SwiftUI

/// 应用主布局
struct AppLayoutView: View {
    @LumiTheme private var theme
    @ObservedObject var kernel: LumiKernel

    @State private var isRailVisible: Bool = true
    @State private var isActivityBarVisible: Bool = true
    @State private var isPanelVisible: Bool = true
    @State private var isChatVisible: Bool = true
    @State private var isContentVisible: Bool = true

    init(kernel: LumiKernel) {
        self.kernel = kernel
    }

    var body: some View {
        VStack(spacing: 0) {
            AppTitleToolbar(kernel: kernel)
            AppDivider()

            HStack(spacing: 0) {
                if isActivityBarVisible {
                    ActivityBar(kernel: kernel)
                    AppDivider(.vertical)
                }
                if isRailVisible {
                    RailView(kernel: kernel)
                    AppDivider(.vertical)
                }
                if isPanelVisible {
                    PanelView(kernel: kernel)
                }
                if isChatVisible {
                    if isPanelVisible {
                        AppDivider(.vertical)
                    }
                    ChatView(kernel: kernel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            AppDivider()
            StatusBar(kernel: kernel)
        }
        .frame(minWidth: 1180, minHeight: 560)
        .background(theme.background)
        .ignoresSafeArea()
        .onRailVisibleDidChange { visible in
            isRailVisible = visible
        }
        .onActivityBarVisibleDidChange { visible in
            isActivityBarVisible = visible
        }
        .onPanelVisibleDidChange { visible in
            isPanelVisible = visible
        }
        .onAppear {
            isRailVisible = kernel.layoutManager?.isRailVisible ?? true
            isActivityBarVisible = kernel.layoutManager?.isActivityBarVisible ?? true
            isPanelVisible = kernel.layoutManager?.isPanelVisible ?? true
            isChatVisible = kernel.layoutManager?.isChatVisible ?? true
            isContentVisible = kernel.layoutManager?.isContentVisible ?? true
        }
    }
}
