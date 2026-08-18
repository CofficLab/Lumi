import KernelCore
import LumiUI
import ProviderDocsView
import SwiftUI

/// 插件管理页右侧的详情面板。
///
/// 展示插件元信息（分类图标 + 名称 + 阶段标签 + 描述）、启用状态控件，
/// 以及内容区。内容区优先展示插件通过 `DocsViewProviding` 贡献的 about 视图
/// （按插件 id 匹配 `aboutEntries`）；未贡献时回退到默认 about 视图
/// （基于 `metadata` 生成的 Hero + 只读信息区），保证每个插件都有 about 页。
/// 不可配置的插件（required）会展示对应的策略标签。
///
/// UI 结构对齐旧版：header + 分隔线 + 内容区。旧版直接调用
/// `pluginAboutView(kernel:)` 展示 about 视图；新版 `SuperPlugin` 无该声明点，
/// 由插件在 `onBoot` 中通过 `DocsViewProviding.addAbout(_:)` 注入，
/// 此处按 id 匹配并展示。
struct PluginSettingsDetailView: View {
    @LumiTheme private var theme

    let kernel: KernelCoreContainer
    let plugin: any SuperPlugin

    /// 文档视图提供器：按插件 id 匹配 about 条目。
    let docsProvider: (any DocsViewProviding)?

    init(
        kernel: KernelCoreContainer,
        plugin: any SuperPlugin,
        docsProvider: (any DocsViewProviding)? = nil
    ) {
        self.kernel = kernel
        self.plugin = plugin
        self.docsProvider = docsProvider
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                AppDivider()
                aboutContent
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

            // 启用状态控件置于右上角（可交互：运行时启停 + 持久化）
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

    /// 内容区：优先展示插件贡献的 about 视图；未贡献时回退到默认 about 视图。
    @ViewBuilder
    private var aboutContent: some View {
        if let aboutEntry {
            aboutEntry.makeView()
                .frame(maxWidth: .infinity, alignment: .topLeading)
        } else {
            defaultAboutView
        }
    }

    /// 当前插件贡献的 about 条目（按 id 匹配 `DocsViewProviding.aboutEntries`）。
    private var aboutEntry: DocsEntry? {
        docsProvider?.aboutEntries.first(where: { $0.id == plugin.id })
    }

    /// 默认 about 视图：基于 metadata 生成的 Hero + 只读信息区，
    /// 保证未贡献 about 的插件也有完整的关于页。
    private var defaultAboutView: some View {
        VStack(alignment: .leading, spacing: 18) {
            LandingHero(
                icon: plugin.metadata.category.systemImage,
                tagline: aboutTagline,
                chips: [
                    plugin.metadata.category.displayName,
                    plugin.metadata.stage.displayName,
                ],
                metrics: [
                    .init(value: plugin.metadata.version, label: PluginPluginManagerText.versionLabel),
                    .init(value: policyMetricValue, label: PluginPluginManagerText.policyLabel),
                ]
            )
            pluginInfoContent
        }
    }

    /// 默认 about 视图 Hero 的标语：优先插件描述，缺失时用兜底文案。
    private var aboutTagline: String {
        plugin.metadata.description.isEmpty
            ? PluginPluginManagerText.noDetailsHint
            : plugin.metadata.description
    }

    /// 策略指标的展示值（与 `policyDescription` 口径一致）。
    private var policyMetricValue: String {
        switch plugin.metadata.policy {
        case .required, .alwaysOn:
            PluginPluginManagerText.alwaysOn
        case .enabledByDefault, .disabledByDefault:
            kernel.isPluginEnabled(id: plugin.id)
                ? PluginPluginManagerText.enabled
                : PluginPluginManagerText.disabled
        }
    }

    /// 只读插件信息区（默认 about 视图的补充信息区）。
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
