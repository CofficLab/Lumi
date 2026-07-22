import LumiKernel
import LumiLocalizationKit
import LumiUI
import SwiftUI

struct PluginSettingsPage: View {
    @LumiTheme private var theme
    @ObservedObject var kernel: LumiKernel
    @State private var selectedPluginID: String?
    @State private var searchText = ""

    private var plugins: [LumiPlugin] {
        kernel.pluginManager.allPlugins
    }

    private var filteredPlugins: [LumiPlugin] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return plugins }
        return plugins.filter { plugin in
            plugin.name.localizedCaseInsensitiveContains(keyword)
                || plugin.id.localizedCaseInsensitiveContains(keyword)
        }
    }

    private var selectedPlugin: LumiPlugin? {
        if let selectedPluginID,
           let plugin = plugins.first(where: { $0.id == selectedPluginID }) {
            return plugin
        }
        return filteredPlugins.first ?? plugins.first
    }

    var body: some View {
        AppSettingsContentScaffold(scrollsContent: false, maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 14) {
                headerStats

                HStack(spacing: 0) {
                    pluginListPane
                        .frame(width: 300)
                        .frame(maxHeight: .infinity)

                    AppDivider(.vertical)

                    pluginDetailPane
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(minHeight: 520, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(theme.divider, lineWidth: 1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onAppear {
            if selectedPluginID == nil {
                selectedPluginID = selectedPlugin?.id
            }
        }
        .onChange(of: filteredPlugins.map(\.id)) { _, ids in
            guard let selectedPluginID,
                  ids.contains(selectedPluginID)
            else {
                self.selectedPluginID = ids.first
                return
            }
        }
    }

    private var headerStats: some View {
        HStack(spacing: 10) {
            Label(
                String(format: LumiLocalization.string("%lld Plugins", bundle: .module), plugins.count),
                systemImage: "puzzlepiece.extension"
            )
            Spacer()
        }
        .font(.appCaption)
        .foregroundStyle(theme.textSecondary)
    }

    private var pluginListPane: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                AppSearchBar(
                    text: $searchText,
                    placeholder: LocalizedStringKey(LumiLocalization.string("Search plugins", bundle: .module))
                )
            }
            .padding(12)

            AppDivider()

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredPlugins, id: \.id) { plugin in
                        pluginListRow(plugin)
                    }

                    if filteredPlugins.isEmpty {
                        AppEmptyState(
                            icon: "magnifyingglass",
                            title: LumiLocalization.string("No plugins found", bundle: .module)
                        )
                        .padding(.vertical, 32)
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: .infinity)
        }
        .appSurface(style: .panel, cornerRadius: 0)
    }

    private func pluginListRow(_ plugin: LumiPlugin) -> some View {
        let isSelected = selectedPluginID == plugin.id

        return AppListRow(isSelected: isSelected, action: { selectedPluginID = plugin.id }) {
            HStack(alignment: .top, spacing: 10) {
                VStack(spacing: 6) {
                    Image(systemName: "puzzlepiece.extension")
                        .font(.appBody)
                        .foregroundStyle(isSelected ? theme.primary : theme.textSecondary)
                        .frame(width: 22, height: 22)

                    Circle()
                        .fill(theme.success)
                        .frame(width: 6, height: 6)
                }
                .frame(width: 22)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(plugin.name)
                            .font(.appCaptionEmphasized)
                            .foregroundStyle(theme.textPrimary)
                            .lineLimit(1)
                    }

                    Text(plugin.id)
                        .font(.appMicro)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 44)
            }
            .overlay(alignment: .topTrailing) {
                AppTag(
                    plugin.policy == .alwaysOn
                        ? LumiLocalization.string("Always On", bundle: .module)
                        : LumiLocalization.string("Enabled", bundle: .module),
                    style: .accent
                )
            }
        }
    }

    @ViewBuilder
    private var pluginDetailPane: some View {
        if let selectedPlugin {
            PluginSettingsDetailView(kernel: kernel, plugin: selectedPlugin)
        } else {
            AppEmptyState(
                icon: "puzzlepiece.extension",
                title: LumiLocalization.string("Select a plugin", bundle: .module)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct PluginSettingsDetailView: View {
    @LumiTheme private var theme
    let kernel: LumiKernel
    let plugin: LumiPlugin

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                policyTag
                AppDivider()
                pluginSettingsContent
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appSurface(style: .panel, cornerRadius: 0)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(theme.primary)
                .frame(width: 64, height: 64)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(theme.appAccentSoftFill)
                )

            VStack(alignment: .leading, spacing: 7) {
                Text(plugin.name)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)

                Text(plugin.id)
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(String(format: LumiLocalization.string("Order: %d", bundle: .module), plugin.order))
                    .font(.appMicro)
                    .foregroundStyle(theme.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var policyTag: some View {
        if plugin.policy == .alwaysOn {
            AppTag(
                LumiLocalization.string("Always On", bundle: .module),
                systemImage: "lock.fill"
            )
        } else {
            AppTag(
                LumiLocalization.string("Opt-Out", bundle: .module),
                systemImage: "checkmark.circle"
            )
        }
    }

    @ViewBuilder
    private var pluginSettingsContent: some View {
        if let about = plugin.pluginAboutView(kernel: kernel) {
            about
        } else {
            AppEmptyState(
                icon: "info.circle",
                title: LumiLocalization.string("No details provided", bundle: .module),
                description: LumiLocalization.string(
                    "The plugin author did not provide a details view.",
                    bundle: .module
                )
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
