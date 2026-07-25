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
        VStack(spacing: 0) {
            AppTitleToolbar(kernel: kernel)
            AppDivider()

            HStack(spacing: 0) {
                ActivityBar(kernel: kernel)
                    .frame(maxHeight: .infinity)
                AppDivider(.vertical)

                if isRailVisible, kernel.layoutManager?.layoutState.activeViewContainerID != nil {
                    RailView(kernel: kernel)
                        .frame(maxWidth: 240, maxHeight: .infinity)
                    AppDivider(.vertical)
                }

                if kernel.layoutManager?.layoutState.activeViewContainerID != nil {
                    PanelView(kernel: kernel)
                        .frame(maxWidth: .infinity)
                } else {
                    WelcomeView()
                        .frame(maxWidth: .infinity)
                }

                if isChatVisible, kernel.layoutManager?.layoutState.activeViewContainerID != nil {
                    AppDivider(.vertical)
                    ChatView(kernel: kernel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                Spacer()
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
}
