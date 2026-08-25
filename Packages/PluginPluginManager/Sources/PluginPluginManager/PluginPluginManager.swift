import KernelCore
import ProviderDocsView
import ProviderSettingView
import ProviderPromptSuggestion
import SwiftUI

/// 插件管理插件（新版本，SuperPlugin 架构）
///
/// 复刻旧版 `PluginManagerPlugin`（KernelLumi/LumiPlugin）：
/// 在设置界面注册「插件管理」入口，枚举并展示所有已注册插件
/// （列表 / 搜索 / 分类筛选 / 阶段徽标 / 启用状态 / 详情），
/// UI 与旧版几乎一致。
///
/// 启用开关可交互：点击调用内核 `enablePlugin` / `disablePlugin` 完成
/// **运行时启停 + 贡献重建 + 持久化**，启用状态写入原插件数据目录
/// （`PluginEnabledStateStore`，旧版同目录、零迁移）。
///
/// - 位置：`order = 90`，与旧版一致，内核启动早期完成设置入口注册。
/// - 策略：`.required`（宿主必需，语义对应旧版 `.alwaysOn`），本插件自身不可被禁用。
@MainActor
public final class PluginPluginManager: SuperPlugin, PromptSuggestionContributing {
    public let id = "com.coffic.lumi.plugin.plugin-manager"
    public let order = 90

    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.plugin-manager",
        name: "插件管理",
        description: "管理所有已注册插件。",
        version: "1.0.0",
        category: .system,
        stage: .stable,
        policy: .required
    )

    public init() {}

    public var promptSuggestions: [PromptSuggestion] { [
        PromptSuggestion(id: "\(id).browse", title: "浏览插件", systemImage: "puzzlepiece.extension", action: .openSettingsTab(id), style: .additive)
    ] }

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let settings = kernel.resolveProvider((any SettingViewProviding).self) else {
            // 设置视图未注册：优雅降级，不贡献入口。
            return
        }

        // 捕获 docs provider 引用，供插件管理详情面板展示各插件的 about 视图。
        let docsProvider = kernel.resolveProvider((any DocsViewProviding).self)

        let entry = SettingEntryItem(
            id: "plugin-manager",
            title: "插件管理",
            systemImage: "puzzlepiece.extension",
            order: 3
        ) { [docsProvider] in
            PluginManagementView(kernel: kernel, docsProvider: docsProvider)
        }

        settings.addEntries([entry])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any SettingViewProviding).self)?
            .removeEntries(ids: ["plugin-manager"])
    }
}
