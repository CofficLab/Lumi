import SwiftUI

/// 编辑器插件详情弹窗视图
struct EditorLoadedPluginsDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var editorVM: EditorVM
    @StateObject private var viewModel = EditorLoadedPluginsViewModel()

    private var rowBackground: Color {
        colorScheme == .light
            ? DesignTokens.Color.semantic.primary.opacity(0.06)
            : DesignTokens.Color.semantic.primary.opacity(0.14)
    }

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
            viewModel.refresh(from: editorVM)
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Text(String(localized: "Editor Plugins", table: "EditorLoadedPlugins"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

            Spacer()

            Button {
                viewModel.refresh(from: editorVM)
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }
            .buttonStyle(.plain)
            .help(String(localized: "Refresh", table: "EditorLoadedPlugins"))
        }
    }

    private var countView: some View {
        Text(
            String(
                format: String(localized: "Loaded %lld plugin(s)", table: "EditorLoadedPlugins"),
                Int64(viewModel.enabledPlugins.count)
            )
        )
        .font(.system(size: 11))
        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
    }

    private var emptyView: some View {
        Text(String(localized: "No editor plugins loaded", table: "EditorLoadedPlugins"))
            .font(.system(size: 12))
            .foregroundColor(DesignTokens.Color.semantic.textTertiary)
            .padding(.vertical, 8)
    }

    private var pluginList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(viewModel.enabledPlugins) { plugin in
                    EditorLoadedPluginRowView(plugin: plugin, rowBackground: rowBackground)
                }
            }
        }
        .frame(minHeight: 300)
    }
}

/// 单个已加载插件的行视图
private struct EditorLoadedPluginRowView: View {
    let plugin: EditorLoadedPluginsViewModel.PluginInfo
    let rowBackground: Color

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Color.semantic.primary)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(plugin.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                Text(plugin.description)
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    .lineLimit(2)
                Text(plugin.id)
                    .font(.system(size: 10))
                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
    }
}
