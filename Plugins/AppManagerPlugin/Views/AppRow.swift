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

            // 操作按钮（悬停时显示）
            if isHovering {
                HStack(spacing: 8) {
                    Button(action: {
                        viewModel.revealInFinder(app)
                    }) {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.bordered)
                    .help("在 Finder 中显示")

                    Button(action: {
                        viewModel.openApp(app)
                    }) {
                        Image.play
                    }
                    .buttonStyle(.bordered)
                    .help("打开应用")

                    Button(action: {
                        viewModel.selectedApp = app
                    }) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderedProminent)
                    .help("卸载应用")
                }
                .transition(.opacity)
            }
        }
        .padding(12)
        .background(.background)
        .roundedMedium()
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            Button("在 Finder 中显示") {
                viewModel.revealInFinder(app)
            }

            Button("打开") {
                viewModel.openApp(app)
            }

            Divider()

            Button("卸载", role: .destructive) {
                viewModel.selectedApp = app
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
