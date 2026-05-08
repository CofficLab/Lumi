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
                    .fill(Color(hex: "98989E").opacity(0.3))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image.appleTerminal
                            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                // 应用名称
                Text(app.displayName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

                // Bundle ID 和版本
                HStack(spacing: 8) {
                    if let identifier = app.bundleIdentifier {
                        Text(identifier)
                            .font(.caption)
                            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    }

                    if let version = app.version {
                        Text("•")
                            .foregroundColor(Color(hex: "98989E"))

                        Text(version)
                            .font(.caption)
                            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    }
                }

                // 大小
                Text(app.formattedSize)
                    .font(.caption)
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
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
        .inRootView()
        .withDebugBar()
}
