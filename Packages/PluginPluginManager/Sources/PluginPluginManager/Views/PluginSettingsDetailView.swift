import KernelCore
import LumiUI
import SwiftUI

/// 插件管理页右侧的详情面板。
///
/// 展示插件元信息（分类图标 + 名称 + 阶段标签 + 描述）、启用状态控件，
/// 以及只读的插件信息区（分类 / 版本 / 策略 / 标识）。
/// 不可配置的插件（required）会展示对应的策略标签。
///
/// UI 结构对齐旧版：header + 分隔线 + 内容区。
/// 旧版内容区展示插件自带的 about 视图；新版 `SuperPlugin` 无该声明点，
/// 故改为展示插件元信息（当前阶段仅展示）。
struct PluginSettingsDetailView: View {
    @LumiTheme private var theme

    let kernel: KernelCoreContainer
    let plugin: any SuperPlugin

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                AppDivider()
                pluginInfoContent
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
                    Text(plugin.metadata.name)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)

                    AppTag(
                        plugin.metadata.stage.displayName,
                        style: plugin.metadata.stage == .stable ? .accent : .subtle
                    )
                }

                if !plugin.metadata.description.isEmpty {
                    Text(plugin.metadata.description)
                        .font(.appCaption)
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 启用状态控件置于右上角（当前仅展示）
            PluginEnableControl(kernel: kernel, plugin: plugin)
                .id(plugin.id)
                .fixedSize()
        }
    }

    /// 头部左侧的大号分类图标。
    private var categoryIcon: some View {
        Image(systemName: plugin.metadata.category.systemImage)
            .font(.system(size: 38, weight: .semibold))
            .foregroundStyle(theme.primary)
            .frame(width: 64, height: 64)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(theme.appAccentSoftFill)
            )
    }

    // MARK: - Content

    /// 只读插件信息区（当前阶段仅展示）。
    private var pluginInfoContent: some View {
        VStack(spacing: 8) {
            AppSettingRow(
                title: PluginPluginManagerText.categoryLabel,
                description: plugin.metadata.category.displayName,
                icon: plugin.metadata.category.systemImage
            ) {
                EmptyView()
            }

            AppSettingRow(
                title: PluginPluginManagerText.versionLabel,
                description: plugin.metadata.version,
                icon: "number"
            ) {
                EmptyView()
            }

            AppSettingRow(
                title: PluginPluginManagerText.policyLabel,
                description: policyDescription,
                icon: "lock.shield"
            ) {
                EmptyView()
            }

            AppSettingRow(
                title: PluginPluginManagerText.identifierLabel,
                description: plugin.id,
                icon: "number.circle"
            ) {
                EmptyView()
            }
        }
    }

    private var policyDescription: String {
        switch plugin.metadata.policy {
        case .required, .alwaysOn:
            PluginPluginManagerText.alwaysOn
        case .enabledByDefault, .disabledByDefault:
            kernel.isPluginEnabled(id: plugin.id)
                ? PluginPluginManagerText.enabled
                : PluginPluginManagerText.disabled
        }
    }
}
