import LumiUI
import SwiftUI

/// App 插件详情弹窗视图
struct AppLoadedPluginsDetailView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @StateObject private var viewModel = AppLoadedPluginsViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerView
            countView

            if viewModel.enabledPlugins.isEmpty {
                emptyView
            } else {
                pluginList
            }
        }
        .onAppear {
            viewModel.refresh()
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Text(String(localized: "App Plugins", table: "AppLoadedPlugins"))
                .font(.appCallout)
                .foregroundColor(theme.textPrimary)

            Spacer()

            Button {
                viewModel.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.appMicroEmphasized)
                    .foregroundColor(theme.textSecondary)
            }
            .buttonStyle(.plain)
            .help(String(localized: "Refresh", table: "AppLoadedPlugins"))
        }
    }

    private var countView: some View {
        Text(
            String(
                format: String(localized: "Loaded %lld plugin(s)", table: "AppLoadedPlugins"),
                Int64(viewModel.enabledPlugins.count)
            )
        )
        .font(.appMicro)
        .foregroundColor(theme.textSecondary)
    }

    private var emptyView: some View {
        Text(String(localized: "No app plugins loaded", table: "AppLoadedPlugins"))
            .font(.appCaption)
            .foregroundColor(theme.textTertiary)
            .padding(.vertical, 8)
    }

    private var pluginList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(viewModel.enabledPlugins) { plugin in
                    AppLoadedPluginRowView(plugin: plugin)
                }
            }
        }
        .frame(minHeight: 300)
    }
}

/// 单个已加载插件的行视图
private struct AppLoadedPluginRowView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let plugin: AppLoadedPluginsViewModel.PluginInfo

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.appMicro)
                .foregroundColor(theme.primary)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(plugin.displayName)
                    .font(.appCaptionEmphasized)
                    .foregroundColor(theme.textPrimary)
                Text(plugin.description)
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(2)
                Text(plugin.id)
                    .font(.appMicro)
                    .foregroundColor(theme.textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .appSurface(style: .custom(theme.appAccentSoftFill), cornerRadius: 8)
    }
}
