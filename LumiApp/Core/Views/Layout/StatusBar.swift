import SwiftUI

/// 底部状态栏视图
struct StatusBar: View {
    @EnvironmentObject var pluginProvider: PluginVM
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        let theme = themeManager.activeAppTheme
        let statusBarLeadingViews = pluginProvider.getStatusBarLeadingViews()
        let statusBarCenterViews = pluginProvider.getStatusBarCenterViews()
        let statusBarTrailingViews = pluginProvider.getStatusBarTrailingViews()
        let hasLeadingViews = !statusBarLeadingViews.isEmpty
        let hasCenterViews = !statusBarCenterViews.isEmpty
        let hasTrailingViews = !statusBarTrailingViews.isEmpty

        return Group {
            if hasLeadingViews || hasCenterViews || hasTrailingViews {
                HStack(spacing: 12) {
                    // 左侧视图
                    if hasLeadingViews {
                        HStack(spacing: 12) {
                            ForEach(statusBarLeadingViews.indices, id: \.self) { index in
                                statusBarLeadingViews[index]
                                    .id("status_bar_leading_\(index)")
                            }
                        }
                    }

                    Spacer()

                    // 中间视图
                    if hasCenterViews {
                        HStack(spacing: 12) {
                            ForEach(statusBarCenterViews.indices, id: \.self) { index in
                                statusBarCenterViews[index]
                                    .id("status_bar_center_\(index)")
                            }
                        }
                    }

                    Spacer()

                    // 右侧视图
                    if hasTrailingViews {
                        HStack(spacing: 12) {
                            ForEach(statusBarTrailingViews.indices, id: \.self) { index in
                                statusBarTrailingViews[index]
                                    .id("status_bar_trailing_\(index)")
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 32)
                .foregroundColor(.white)
                .appSurface(style: .custom(statusBarBackground), cornerRadius: 0)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(theme.workspaceTextColor().opacity(0.18))
                        .frame(height: 1)
                }
            }
        }
    }

    private var statusBarBackground: Color {
        let theme = themeManager.activeAppTheme
        // 状态栏使用主题的深色氛围色，确保与整体主题协调
        return theme.isDarkTheme
            ? theme.atmosphereColors().deep
            : theme.accentColors().primary
    }
}
