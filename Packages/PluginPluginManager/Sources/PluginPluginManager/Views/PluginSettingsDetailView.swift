import KernelCore
import LumiUI
import ProviderDocsView
import ProviderPluginManaging
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

    let manager: any PluginManaging
    let plugin: any SuperPlugin

    /// 文档视图提供器：按插件 id 匹配 about 条目。
    let docsProvider: (any DocsViewProviding)?

    init(
        manager: any PluginManaging,
        plugin: any SuperPlugin,
        docsProvider: (any DocsViewProviding)? = nil
    ) {
        self.manager = manager
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

                    if plugin.metadata.stage != .stable {
                        AppTag(
                            plugin.metadata.stage.displayName,
                            style: .subtle
                        )
                    }
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
            PluginEnableControl(manager: manager, plugin: plugin)
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
        PluginDefaultAboutView(
            metadata: plugin.metadata,
            isEnabled: manager.isEnabled(id: plugin.id)
        )
    }
}
