import KernelLumi
import LumiUI
import SwiftUI

/// 说明书浏览器 —— 主从式布局:左侧为提供了说明书的插件名列表,
/// 右侧为选中插件的说明书内容(由 `LumiPlugin.pluginManualView` 贡献)。
///
/// 由 设置 → 通用 → 新手引导 分区的「说明书」行以 sheet 展示。
struct ManualsBrowserView: View {
    let kernel: KernelLumi

    @State private var selectedPluginID: String?

    /// 所有提供了说明书的插件,按插件加载顺序排列。
    ///
    /// 不受插件启用状态影响——说明书是帮助内容,禁用的插件依然可以查阅
    /// (便于用户了解功能后再决定是否启用)。
    private var plugins: [LumiPlugin] {
        kernel.pluginManager.allPlugins
            .filter { $0.pluginManualView(kernel: kernel) != nil }
    }

    private var selectedPlugin: LumiPlugin? {
        plugins.first { $0.id == selectedPluginID } ?? plugins.first
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Divider()

            detail
        }
        .frame(minWidth: 860, minHeight: 560)
        .onAppear {
            if selectedPluginID == nil {
                selectedPluginID = plugins.first?.id
            }
        }
    }

    // MARK: - 左侧插件列表

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "book")
                    .foregroundStyle(.secondary)
                Text(LumiPluginLocalization.string("User Manuals", bundle: .module))
                    .font(.headline)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(plugins, id: \.id) { plugin in
                        sidebarRow(plugin)
                    }
                }
                .padding(10)
            }
        }
        .frame(width: 220)
        .background(Color.primary.opacity(0.03))
    }

    private func sidebarRow(_ plugin: LumiPlugin) -> some View {
        let isSelected = plugin.id == selectedPlugin?.id
        return Button {
            selectedPluginID = plugin.id
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "book")
                    .font(.system(size: 13))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                Text(plugin.name)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 右侧说明书内容

    private var detail: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let plugin = selectedPlugin {
                HStack(spacing: 10) {
                    Text(plugin.name)
                        .font(.headline)
                    Spacer()
                    AppIconButton(systemImage: "xmark") {
                        dismiss()
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)

                Divider()

                ScrollView {
                    plugin.pluginManualView(kernel: kernel)
                        .padding(22)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "book")
                        .font(.system(size: 34))
                        .foregroundStyle(.secondary)
                    Text(LumiPluginLocalization.string("No manuals are available yet.", bundle: .module))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
}
