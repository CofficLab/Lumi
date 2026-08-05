import LumiUI
import SwiftUI

/// 应用行视图
struct AppRow: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let app: AppModel
    @ObservedObject var viewModel: AppManagerViewModel

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
                // 应用名称 + Bundle ID + 版本
                AppIdentityRow(
                    title: app.displayName,
                    metadata: [
                        app.bundleIdentifier ?? "",
                        app.version ?? ""
                    ],
                    titleColor: theme.textPrimary,
                    metadataColor: theme.textSecondary
                )

                // 大小
                AppSizeLabel(bytes: app.size)
            }

            Spacer()
        }
        .contextMenu {
            AppContextMenuRow(
                LocalizedStringKey(PluginAppManagerLocalization.string("Show in Finder")),
                systemImage: "folder",
                action: { viewModel.revealInFinder(app) }
            )

            AppContextMenuRow(
                LocalizedStringKey(PluginAppManagerLocalization.string("Open")),
                systemImage: "play.fill",
                action: { viewModel.openApp(app) }
            )
        }
    }
}
