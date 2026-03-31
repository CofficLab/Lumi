import SwiftUI

/// 底部状态栏视图
struct StatusBar: View {
    @EnvironmentObject var pluginProvider: PluginVM
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let statusBarLeadingViews = pluginProvider.getStatusBarLeadingViews()
        let statusBarTrailingViews = pluginProvider.getStatusBarTrailingViews()
        let hasLeadingViews = !statusBarLeadingViews.isEmpty
        let hasTrailingViews = !statusBarTrailingViews.isEmpty

        return Group {
            if hasLeadingViews || hasTrailingViews {
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
                        .fill(statusBarTopDivider)
                        .frame(height: 1)
                }
            }
        }
    }

    private var statusBarBackground: Color {
        #if DEBUG
        // Debug 模式使用黄色调
        switch colorScheme {
        case .light:
            return Color(hex: "F5A623")  // 金黄色
        case .dark:
            return Color(hex: "D48806")  // 深金黄色
        @unknown default:
            return Color(hex: "D48806")
        }
        #else
        // Release 模式使用蓝色调
        switch colorScheme {
        case .light:
            return Color(hex: "007ACC")
        case .dark:
            return Color(hex: "0E639C")
        @unknown default:
            return Color(hex: "0E639C")
        }
        #endif
    }

    private var statusBarTopDivider: Color {
        switch colorScheme {
        case .light:
            return Color.black.opacity(0.18)
        case .dark:
            return Color.white.opacity(0.18)
        @unknown default:
            return Color.white.opacity(0.18)
        }
    }
}
