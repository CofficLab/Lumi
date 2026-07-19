import LumiUI
import SwiftUI

/// 应用行视图
struct AppRow: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

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
                Color.clear
                    .appSurface(style: .subtle, cornerRadius: 10)
                    .frame(width: 48, height: 48)
            }

            VStack(alignment: .leading, spacing: 4) {
                // 应用名称
                Text(app.displayName)
                    .font(.appBodyEmphasized)
                    .foregroundColor(theme.textPrimary)

                // Bundle ID 和版本
                HStack(spacing: 8) {
                    if let identifier = app.bundleIdentifier {
                        Text(identifier)
                            .font(.appCaption)
                            .foregroundColor(theme.textSecondary)
                    }

                    if let version = app.version {
                        Text(verbatim: LumiPluginLocalization.string("•", bundle: .module))
                            .foregroundColor(theme.textTertiary)

                        Text(version)
                            .font(.appCaption)
                            .foregroundColor(theme.textSecondary)
                    }
                }

                // 大小
                Text(app.formattedSize)
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
            }

            Spacer()
        }
        .contextMenu {
            Button(PluginAppManagerLocalization.string("Show in Finder")) {
                viewModel.revealInFinder(app)
            }

            Button(PluginAppManagerLocalization.string("Open")) {
                viewModel.openApp(app)
            }
        }
    }
}
