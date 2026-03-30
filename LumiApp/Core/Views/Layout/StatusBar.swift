import SwiftUI

/// 底部状态栏视图
struct StatusBar: View {
    @EnvironmentObject var pluginProvider: PluginVM
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let statusBarViews = pluginProvider.getStatusBarViews()

        return Group {
            if !statusBarViews.isEmpty {
                HStack(spacing: 12) {
                    ForEach(statusBarViews.indices, id: \.self) { index in
                        statusBarViews[index]
                            .id("status_bar_\(index)")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 32)
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
        switch colorScheme {
        case .light:
            return Color(hex: "007ACC")
        case .dark:
            return Color(hex: "0E639C")
        @unknown default:
            return Color(hex: "0E639C")
        }
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
