import LumiKernel
import LumiUI
import SwiftUI

/// 插件设置页（最小实现）
///
/// 仅展示已注册插件列表，启用/禁用等完整能力随插件迁移恢复。
struct PluginSettingsPage: View {
    @LumiTheme private var theme
    @ObservedObject var kernel: LumiKernel

    private var plugins: [LumiPlugin] {
        kernel.plugin?.allPlugins ?? []
    }

    var body: some View {
        AppSettingsContentScaffold(maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 14) {
                headerStats

                if plugins.isEmpty {
                    AppEmptyState(
                        icon: "puzzlepiece.extension",
                        title: "没有已注册插件"
                    )
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    pluginList
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var headerStats: some View {
        HStack(spacing: 10) {
            Label(
                "\(plugins.count) 个插件",
                systemImage: "puzzlepiece.extension"
            )
            Spacer()
        }
        .font(.appCaption)
        .foregroundStyle(theme.textSecondary)
    }

    private var pluginList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(plugins, id: \.id) { plugin in
                    pluginRow(plugin)
                }
            }
            .padding(8)
        }
        .appSurface(style: .panel, cornerRadius: 0)
    }

    private func pluginRow(_ plugin: LumiPlugin) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "puzzlepiece.extension")
                .font(.appBody)
                .foregroundStyle(theme.primary)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(plugin.name)
                    .font(.appCaptionEmphasized)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)

                Text(plugin.id)
                    .font(.appMicro)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
