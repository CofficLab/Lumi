import LumiUI
import SwiftUI

/// 插件管理页右侧的详情面板。
///
/// View 只读取 `PluginManagementViewModel`，不直接依赖插件管理 Provider、Docs
/// Provider 或具体插件实例。
struct PluginSettingsDetailView: View {
    @LumiTheme private var theme
    @ObservedObject private var viewModel: PluginManagementViewModel

    init(viewModel: PluginManagementViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        Group {
            if viewModel.selectedPlugin != nil {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        AppDivider()
                        aboutContent
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            } else {
                AppEmptyState(
                    icon: "puzzlepiece.extension",
                    title: PluginPluginManagerText.selectPlugin
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appSurface(style: .panel, cornerRadius: 0)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            categoryIcon

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(selectedPlugin.metadata.name)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)

                    if selectedPlugin.metadata.stage != .stable {
                        AppTag(selectedPlugin.metadata.stage.displayName, style: .subtle)
                    }
                }

                if !selectedPlugin.metadata.description.isEmpty {
                    Text(selectedPlugin.metadata.description)
                        .font(.appCaption)
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            PluginEnableControl(
                viewModel: viewModel,
                pluginID: selectedPlugin.id
            )
            .id(selectedPlugin.id)
            .fixedSize()
        }
    }

    private var categoryIcon: some View {
        Image(systemName: selectedPlugin.metadata.category.systemImage)
            .font(.system(size: 38, weight: .semibold))
            .foregroundStyle(theme.primary)
            .frame(width: 64, height: 64)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(theme.appAccentSoftFill)
            )
    }

    @ViewBuilder
    private var aboutContent: some View {
        if let aboutEntry = viewModel.aboutEntry(for: selectedPlugin.id) {
            aboutEntry.makeView()
                .frame(maxWidth: .infinity, alignment: .topLeading)
        } else {
            PluginDefaultAboutView(
                metadata: selectedPlugin.metadata,
                isEnabled: selectedPlugin.isEnabled
            )
        }
    }

    private var selectedPlugin: PluginManagementItem {
        guard let selectedPlugin = viewModel.selectedPlugin else {
            preconditionFailure("PluginSettingsDetailView requires a selected plugin")
        }
        return selectedPlugin
    }
}
