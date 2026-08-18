import Foundation
import LumiUI
import ProviderWorkspace
import SwiftUI

@MainActor
struct DefaultRootHostView: View {
    @ObservedObject var provider: DefaultRootViewProvider
    @LumiTheme private var theme

    var body: some View {
        VStack(spacing: 0) {
            if let toolbarView = provider.toolbarView {
                toolbarView
                // 与旧版 AppLayoutView 一致：工具栏下方使用主题分隔线。
                AppDivider()
            }

            HStack(spacing: 0) {
                if provider.showsActivityBar, let activityBarView = provider.activityBarView {
                    activityBarView
                    // 与旧版 AppLayoutView 一致：ActivityBar 右侧使用主题竖向分隔线。
                    AppDivider(.vertical)
                }

                WorkbenchSplitView(provider: provider)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
        .appThemedAppearance()
        .background {
            ThemeWindowAppearanceBridge()
        }
        .environmentObject(AppThemeVM.shared)
        #if os(macOS)
            .ignoresSafeArea()
        #endif
    }
}
