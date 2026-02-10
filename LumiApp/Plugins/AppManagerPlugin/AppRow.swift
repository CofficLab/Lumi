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
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image.appleTerminal
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                // 应用名称
                Text(app.displayName)
                    .font(.headline)

                // Bundle ID 和版本
                HStack(spacing: 8) {
                    if let identifier = app.bundleIdentifier {
                        Text(identifier)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let version = app.version {
                        Text("•")
                            .foregroundStyle(.secondary)

                        Text(version)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // 大小
                Text(app.formattedSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        .hideTabPicker()
        .withNavigation(AppManagerPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
