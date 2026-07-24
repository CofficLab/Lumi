import LumiKernel
import LumiUI
import SwiftUI

/// 应用主布局
struct AppLayoutView: View {
    @LumiTheme private var theme
    @ObservedObject var kernel: LumiKernel

    init(kernel: LumiKernel) {
        self.kernel = kernel
    }

    var body: some View {
        VStack(spacing: 0) {
            AppTitleToolbar(kernel: kernel)
            AppDivider()

            HStack(spacing: 0) {
                ActivityBar(kernel: kernel)
                AppDivider(.vertical)
                RailView(kernel: kernel)
                PanelView(kernel: kernel)
                ChatView(kernel: kernel)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            AppDivider()
            StatusBar(kernel: kernel)
        }
        .frame(minWidth: 1180, minHeight: 560)
        .background(theme.background)
        .ignoresSafeArea()
    }
}
