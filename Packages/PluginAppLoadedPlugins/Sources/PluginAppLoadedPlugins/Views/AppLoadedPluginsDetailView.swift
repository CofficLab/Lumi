import LumiUI
import SwiftUI

struct AppLoadedPluginsDetailView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @StateObject private var viewModel: AppLoadedPluginsViewModel

    init(pluginProvider: @escaping @MainActor () -> [LoadedPluginInfo]) {
        _viewModel = StateObject(wrappedValue: AppLoadedPluginsViewModel(pluginProvider: pluginProvider))
    }

    var body: some View {
        StatusBarPopoverScaffold(
            title: PluginAppLoadedPluginsLocalization.string("App Plugins"),
            systemImage: "puzzlepiece.extension",
            subtitle: countText
        ) {
            AppIconButton(
                systemImage: "arrow.clockwise",
                action: viewModel.refresh
            )
            .help(PluginAppLoadedPluginsLocalization.string("Refresh"))
        } content: {
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

    private var countText: String {
        String(
            format: PluginAppLoadedPluginsLocalization.string("Loaded %lld plugin(s)"),
            Int64(viewModel.enabledPlugins.count)
        )
    }

    private var emptyView: some View {
        AppEmptyState(
            icon: "puzzlepiece.extension",
            title: LocalizedStringKey(PluginAppLoadedPluginsLocalization.string("No app plugins loaded"))
        )
        .frame(minHeight: 220)
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

private struct AppLoadedPluginRowView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let plugin: LoadedPluginInfo

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
        .appSurface(style: .subtle, cornerRadius: 8)
    }
}
