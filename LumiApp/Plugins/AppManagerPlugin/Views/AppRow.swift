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
                AppImageThumbnail(
                    image: Image(nsImage: icon),
                    size: CGSize(width: 48, height: 48),
                    shape: .none
                )
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppUI.Color.semantic.textTertiary.opacity(0.3))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image.appleTerminal
                            .foregroundColor(AppUI.Color.semantic.textSecondary)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                // 应用名称
                Text(app.displayName)
                    .font(AppUI.Typography.bodyEmphasized)
                    .foregroundColor(AppUI.Color.semantic.textPrimary)

                // Bundle ID 和版本
                HStack(spacing: 8) {
                    if let identifier = app.bundleIdentifier {
                        Text(identifier)
                            .font(.caption)
                            .foregroundColor(AppUI.Color.semantic.textSecondary)
                    }

                    if let version = app.version {
                        Text("•")
                            .foregroundColor(AppUI.Color.semantic.textTertiary)

                        Text(version)
                            .font(.caption)
                            .foregroundColor(AppUI.Color.semantic.textSecondary)
                    }
                }

                // 大小
                Text(app.formattedSize)
                    .font(.caption)
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
            }

            Spacer()
        }
        .contextMenu {
            Button(String(localized: "Show in Finder", table: "AppManager")) {
                viewModel.revealInFinder(app)
            }

            Button(String(localized: "Open", table: "AppManager")) {
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
