import LocalizationKit
import KernelLumi
import LumiUI
import SwiftUI

/// 插件管理页右侧的详情面板。
///
/// 展示插件元信息(分类图标 + 名称 + 阶段标签 + 描述)、
/// 启用/关闭开关,以及由插件自身提供的 `pluginAboutView`。
/// 不可配置的插件(alwaysOn / disabled)会展示对应的策略标签。
///
/// 仅供 `PluginManagementView` 内部使用;标记 `internal` 以允许跨文件引用
/// (若标记 `fileprivate`,其他 Swift 文件中无法解析)。
struct PluginSettingsDetailView: View {
    @LumiTheme private var theme

    let kernel: KernelLumi
    let plugin: LumiPlugin

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                AppDivider()
                pluginSettingsContent
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appSurface(style: .panel, cornerRadius: 0)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            categoryIcon

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(plugin.name)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)

                    AppTag(plugin.stage.displayName, style: plugin.stage == .stable ? .accent : .subtle)
                }

                if !plugin.pluginDescription.isEmpty {
                    Text(plugin.pluginDescription)
                        .font(.appCaption)
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 启用/关闭开关置于右上角
            PluginEnableControl(kernel: kernel, plugin: plugin)
                .id(plugin.id)
                .fixedSize()
        }
    }

    /// 头部左侧的大号分类图标。
    private var categoryIcon: some View {
        Image(systemName: plugin.category.systemImage)
            .font(.system(size: 38, weight: .semibold))
            .foregroundStyle(theme.primary)
            .frame(width: 64, height: 64)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(theme.appAccentSoftFill)
            )
    }

    // MARK: - Content

    @ViewBuilder
    private var pluginSettingsContent: some View {
        if let about = plugin.pluginAboutView(kernel: kernel) {
            about
        } else {
            AppEmptyState(
                icon: "info.circle",
                title: PluginManagerText.string(PluginManagerText.noDetailsProvided),
                description: PluginManagerText.string(PluginManagerText.noDetailsHint)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
