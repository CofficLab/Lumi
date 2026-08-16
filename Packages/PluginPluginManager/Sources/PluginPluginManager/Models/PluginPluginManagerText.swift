import KernelCore
import Foundation

/// 插件管理页用到的文案常量集中管理。
///
/// 与新版本其它插件包（PluginSettingGeneral / PluginThemePack）一致，
/// 直接内联中文文案，不依赖 LocalizationKit / xcstrings。
enum PluginPluginManagerText {
    static let plugins = "插件管理"
    static let pluginsHint = "管理所有已注册插件"
    static let aboutDescription = "列出并展示所有已注册插件。"
    static let searchPlugins = "搜索插件"
    static let noPluginsFound = "未找到插件"
    static let selectPlugin = "选择一个插件"
    static let pluginsCount = "%lld 个插件"
    static let enabledCount = "%lld 已启用"
    static let allCategories = "全部"
    static let alwaysOn = "始终启用"
    static let disabled = "已禁用"
    static let enabled = "已启用"
    static let noDetailsProvided = "无详细信息"
    static let noDetailsHint = "插件作者未提供详情视图。"
    static let enable = "启用"

    // 详情面板信息区
    static let categoryLabel = "分类"
    static let versionLabel = "版本"
    static let policyLabel = "策略"
    static let identifierLabel = "标识"

    // 关于视图
    static let browsePlugins = "浏览实用插件"
    static let coreCapabilities = "核心能力"
    static let whereToFindIt = "入口位置"
    static let settingsEntry = "设置 → 插件管理"
    static let capabilityCatalogTitle = "插件目录"
    static let capabilityCatalogDescription = "一览所有已注册插件。"
    static let capabilitySearchTitle = "搜索"
    static let capabilitySearchDescription = "按名称即时查找插件。"
    static let capabilityFilterTitle = "分类筛选"
    static let capabilityFilterDescription = "按插件分类过滤。"
    static let capabilityDetailTitle = "插件详情"
    static let capabilityDetailDescription = "查看每个插件的描述与阶段。"
    static let capabilityOrderTitle = "排序"
    static let capabilityOrderDescription = "插件按注册顺序展示。"
}

// MARK: - 新版枚举的展示映射（对齐旧版 LumiPluginCategory / Stage / Policy 语义）

// `PluginEnablePolicy.isConfigurable` 由 KernelCore 提供（对齐旧版 `LumiPluginPolicy.isConfigurable`），
// 此处不再重复声明。

extension PluginCategory {
    /// 展示顺序（用于分类筛选标签栏；`allCases` 缺失时作为排序依据）。
    static var displayOrder: [PluginCategory] {
        [
            .core, .chat, .llm, .system, .project, .editor,
            .integration, .design, .general,
        ]
    }

    var displayName: String {
        switch self {
        case .core: "核心"
        case .chat: "聊天"
        case .llm: "模型"
        case .editor: "编辑器"
        case .project: "项目"
        case .system: "系统"
        case .design: "设计"
        case .integration: "集成"
        case .general: "通用"
        }
    }

    var systemImage: String {
        switch self {
        case .core: "cube"
        case .chat: "bubble.left.and.bubble.right"
        case .llm: "cpu"
        case .editor: "chevron.left.forwardslash.chevron.right"
        case .project: "folder"
        case .system: "desktopcomputer"
        case .design: "paintbrush"
        case .integration: "arrow.up.right.square"
        case .general: "puzzlepiece.extension"
        }
    }

    var sortOrder: Int {
        switch self {
        case .core: 10
        case .chat: 15
        case .llm: 20
        case .system: 25
        case .project: 30
        case .editor: 35
        case .integration: 40
        case .design: 45
        case .general: 50
        }
    }
}

extension PluginStage {
    var displayName: String {
        switch self {
        case .experimental: "Experimental"
        case .preview: "Preview"
        case .stable: "Stable"
        case .deprecated: "Deprecated"
        }
    }
}
