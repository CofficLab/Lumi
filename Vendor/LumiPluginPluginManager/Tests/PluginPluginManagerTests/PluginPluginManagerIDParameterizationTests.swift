import Foundation
import KernelCore
import ProviderDocsView
import ProviderPluginManaging
import ProviderPromptSuggestion
import ProviderSettingView
import Testing

@testable import PluginPluginManager

/// 插件 id 参数化（`init(id:)`）的行为守卫。
///
/// 宿主（如 Wakey）用自己的品牌 id 复用本包时，插件 id、`PluginMetadata.id`
/// 与日志子系统都必须跟随注入值变化，否则宿主界面会残留上游品牌。
@MainActor
struct PluginPluginManagerIDParameterizationTests {

    /// 默认 id 保持上游品牌，宿主不传参时行为与 1.2.0 完全一致。
    @Test("默认 id 保持 com.coffic.lumi.plugin.plugin-manager")
    func defaultIDRemainsUpstreamBrand() {
        let plugin = PluginPluginManager()
        #expect(plugin.id == "com.coffic.lumi.plugin.plugin-manager")
        #expect(plugin.metadata.id == "com.coffic.lumi.plugin.plugin-manager")
    }

    /// 宿主注入自定义 id 后，插件 id 与元数据 id 同步跟随。
    @Test("注入自定义 id 后插件 id 与元数据 id 同步跟随")
    func injectedIDPropagatesToMetadata() {
        let plugin = PluginPluginManager(
            id: "com.coffic.wakey.plugin.plugin-manager",
            entryVisibility: .always
        )
        #expect(plugin.id == "com.coffic.wakey.plugin.plugin-manager")
        #expect(plugin.metadata.id == "com.coffic.wakey.plugin.plugin-manager")
    }

    /// 注入 id 后其余元数据（顺序 / 策略 / 分类 / 阶段）不受影响。
    @Test("注入自定义 id 不影响其它元数据")
    func injectedIDKeepsOtherMetadata() {
        let plugin = PluginPluginManager(
            id: "com.coffic.wakey.plugin.plugin-manager",
            entryVisibility: .always
        )
        #expect(plugin.order == 90)
        #expect(plugin.metadata.policy == .required)
        #expect(plugin.metadata.category == .system)
        #expect(plugin.metadata.stage == .stable)
    }

    /// 注入 id 后插件仍能正常注册进内核，注册表 key 使用注入的 id。
    @Test("注入自定义 id 后注册进内核的 key 同步跟随")
    func injectedIDRegistersUnderCustomKey() throws {
        let kernel = KernelCoreContainer()
        let plugin = PluginPluginManager(
            id: "com.coffic.wakey.plugin.plugin-manager",
            entryVisibility: .always
        )

        // `start` 内部会完成注册，不要再单独调用 `registerPlugin`。
        try kernel.start(plugins: [plugin])

        #expect(kernel.isPluginRegistered(id: "com.coffic.wakey.plugin.plugin-manager"))
        #expect(!kernel.isPluginRegistered(id: "com.coffic.lumi.plugin.plugin-manager"))
        #expect(kernel.resolvePlugin(id: "com.coffic.wakey.plugin.plugin-manager") != nil)
    }

    /// 注入 id 后设置入口与 About / Manual 条目都使用注入的 id。
    @Test("注入自定义 id 后设置入口与文档条目同步跟随")
    func injectedIDPropagatesToSettingsAndDocsEntries() throws {
        let settings = DefaultSettingViewProviding()
        let docs = DefaultDocsViewProviding()
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any SettingViewProviding).self, settings)
        try kernel.registerProvider((any DocsViewProviding).self, docs)
        try kernel.registerProvider(
            (any PluginManaging).self,
            DefaultPluginManager(kernel: kernel)
        )

        let plugin = PluginPluginManager(
            id: "com.coffic.wakey.plugin.plugin-manager",
            entryVisibility: .always
        )
        try plugin.onRegister(kernel: kernel)
        try plugin.onBoot(kernel: kernel)
        try plugin.onReady(kernel: kernel)

        // 设置入口 id 是稳定的 "plugin-manager"，与品牌无关。
        #expect(settings.entries.contains { $0.id == "plugin-manager" })

        // Manual 条目使用插件 id，因此跟随注入值。
        #expect(docs.manualEntries.contains { $0.id == "com.coffic.wakey.plugin.plugin-manager" })
        #expect(!docs.manualEntries.contains { $0.id == "com.coffic.lumi.plugin.plugin-manager" })
    }

    /// 注入 id 后提示建议的 id 跟随变化（否则会与上游建议冲突或串台）。
    ///
    /// 提示建议跟随「插件管理」设置入口：入口存在时才注册，所以这里要跑
    /// 完整的 `onBoot` + `onReady`。
    @Test("注入自定义 id 后提示建议 id 同步跟随")
    func injectedIDPropagatesToPromptSuggestion() throws {
        let settings = DefaultSettingViewProviding()
        let suggestions = DefaultPromptSuggestionProvider()
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any SettingViewProviding).self, settings)
        try kernel.registerProvider((any PromptSuggestionProviding).self, suggestions)
        try kernel.registerProvider(
            (any PluginManaging).self,
            DefaultPluginManager(kernel: kernel)
        )

        let plugin = PluginPluginManager(
            id: "com.coffic.wakey.plugin.plugin-manager",
            entryVisibility: .always
        )
        try plugin.onRegister(kernel: kernel)
        try plugin.onBoot(kernel: kernel)
        try plugin.onReady(kernel: kernel)

        let suggestion = suggestions.allSuggestions.first { $0.pluginID == plugin.id }
        #expect(suggestion != nil)
        #expect(suggestion?.id == "com.coffic.wakey.plugin.plugin-manager.browse")
        #expect(suggestion?.action == .openSettingsTab(PluginPluginManager.settingsEntryID))
    }

    /// 注销时按注入的 id 撤回提示建议。
    @Test("注入自定义 id 后注销撤回对应提示建议")
    func injectedIDUnregistersOwnSuggestion() throws {
        let settings = DefaultSettingViewProviding()
        let suggestions = DefaultPromptSuggestionProvider()
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any SettingViewProviding).self, settings)
        try kernel.registerProvider((any PromptSuggestionProviding).self, suggestions)
        try kernel.registerProvider(
            (any PluginManaging).self,
            DefaultPluginManager(kernel: kernel)
        )

        let plugin = PluginPluginManager(
            id: "com.coffic.wakey.plugin.plugin-manager",
            entryVisibility: .always
        )
        try plugin.onRegister(kernel: kernel)
        try plugin.onBoot(kernel: kernel)
        try plugin.onReady(kernel: kernel)
        #expect(suggestions.allSuggestions.contains { $0.id == "com.coffic.wakey.plugin.plugin-manager.browse" })

        try plugin.onUnregister(kernel: kernel)
        #expect(!suggestions.allSuggestions.contains { $0.id == "com.coffic.wakey.plugin.plugin-manager.browse" })
    }
}
