import SwiftUI

/// 应用行视图
struct AppRow: View {
    let app: AppModel
    @ObservedObject var viewModel: AppManagerViewModel

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            // 应用图标
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 48, height: 48)
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(DesignTokens.Color.semantic.textTertiary.opacity(0.3))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image.appleTerminal
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                // 应用名称
                Text(app.displayName)
                    .font(.headline)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                // Bundle ID 和版本
                HStack(spacing: 8) {
                    if let identifier = app.bundleIdentifier {
                        Text(identifier)
                            .font(.caption)
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    }

                    if let version = app.version {
                        Text("•")
                            .foregroundColor(DesignTokens.Color.semantic.textTertiary)

                        Text(version)
                            .font(.caption)
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    }
                }

                // 大小
                Text(app.formattedSize)
                    .font(.caption)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }

            Spacer()
        }
        .contextMenu {
            Button("Show in Finder") {
                viewModel.revealInFinder(app)
            }

            Button("Open") {
                viewModel.openApp(app)
            }
        }
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation(AppManagerPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
