import Foundation
import LumiUI
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
                if let activityBarView = provider.activityBarView {
                    activityBarView
                }

                WorkbenchSplitView(provider: provider)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
        .appThemedAppearance()
        #if os(macOS)
        .background {
            ThemeWindowAppearanceBridge()
        }
        #endif
        .environmentObject(AppThemeVM.shared)
        #if os(macOS)
            .ignoresSafeArea()
        #endif
    }
}
