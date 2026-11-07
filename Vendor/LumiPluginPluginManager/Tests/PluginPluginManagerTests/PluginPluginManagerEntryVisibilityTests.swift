import Foundation
import KernelCore
import ProviderPluginManaging
import ProviderPromptSuggestion
import ProviderSettingView
import Testing

@testable import PluginPluginManager

/// 「插件管理」设置入口的可见性策略（`EntryVisibility`）。
///
/// 背景：宿主的插件策略全是 `required` / `alwaysOn` 时（`isConfigurable` 为
/// false），插件管理页必然是一个永远为空的列表 —— 这样的入口对用户没有意义。
/// 默认策略 `.onlyWhenConfigurablePluginsExist` 让这类宿主跳过注册入口，
/// 且宿主**零配置**即可获得正确行为。
@MainActor
struct PluginPluginManagerEntryVisibilityTests {

    /// 默认策略是 `.onlyWhenConfigurablePluginsExist`：宿主没有可配置插件时
    /// 不注册入口。
    ///
    /// 这条守卫盯住「默认行为反转后又被改回去」这个坑：默认必须是自动判断，
    /// 否则每个宿主都要手工配置一次。
    @Test("默认策略下无可配置插件时不注册入口")
    func defaultVisibilitySkipsEntryWithoutConfigurablePlugins() throws {
        let settings = DefaultSettingViewProviding()
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any SettingViewProviding).self, settings)
        try kernel.registerProvider(
            (any PluginManaging).self,
            DefaultPluginManager(kernel: kernel)
        )

        // 宿主只有一个 required 插件（插件管理器自身），没有可配置插件。
        let plugin = PluginPluginManager()
        try kernel.start(plugins: [plugin])

        #expect(!settings.entries.contains { $0.id == "plugin-manager" })
    }

    /// 默认策略下，宿主有可配置插件时注册入口（宿主零配置即得正确行为）。
    ///
    /// 这条守卫盯住「默认策略判断失效」这个坑：Lumi 主项目有大量可配置插件，
    /// 它的 UI 测试硬断言侧边栏存在「Plugin Manager」入口 —— 宿主不传任何参数
    /// 就必须能显示入口。
    @Test("默认策略下有可配置插件时注册入口")
    func defaultVisibilityRegistersEntryWithConfigurablePlugins() throws {
        let settings = DefaultSettingViewProviding()
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any SettingViewProviding).self, settings)
        try kernel.registerProvider(
            (any PluginManaging).self,
            DefaultPluginManager(kernel: kernel)
        )

        let plugin = PluginPluginManager()
        try kernel.start(plugins: [
            plugin,
            TestPlugin(id: "optional", policy: .enabledByDefault),
        ])

        #expect(settings.entries.contains { $0.id == "plugin-manager" })
    }

    /// `.always` 强制显示：宿主没有可配置插件时也注册入口。
    @Test("always 策略下强制注册入口")
    func alwaysVisibilityRegistersEntryRegardless() throws {
        let settings = DefaultSettingViewProviding()
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any SettingViewProviding).self, settings)
        try kernel.registerProvider(
            (any PluginManaging).self,
            DefaultPluginManager(kernel: kernel)
        )

        let plugin = PluginPluginManager(entryVisibility: .always)
        try kernel.start(plugins: [
            plugin,
            TestPlugin(id: "always-on", policy: .alwaysOn),
        ])

        #expect(settings.entries.contains { $0.id == "plugin-manager" })
    }

    /// 可配置插件的 order 大于插件管理器时，判断仍要看到它。
    ///
    /// 这条守卫盯住「在 `onBoot` 阶段判断」这个坑：`onBoot` 按 order 依次执行，
    /// order 更大的插件此刻还没注册，据此判断会漏掉插件、错误地跳过入口。
    /// 判断必须等到 `onReady`（全部插件已注册）。
    @Test("order 更大的可配置插件也能被判定到")
    func detectsConfigurablePluginRegisteredAfterPluginManager() throws {
        let settings = DefaultSettingViewProviding()
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any SettingViewProviding).self, settings)
        try kernel.registerProvider(
            (any PluginManaging).self,
            DefaultPluginManager(kernel: kernel)
        )

        let plugin = PluginPluginManager()
        // 插件管理器 order = 90，可配置插件 order = 999（更大 → 更晚 boot）。
        try kernel.start(plugins: [
            plugin,
            TestPlugin(id: "late-optional", policy: .disabledByDefault, order: 999),
        ])

        #expect(settings.entries.contains { $0.id == "plugin-manager" })
    }

    /// `disabled` 策略的插件被内核彻底排除，既不注册也不启动 —— 不是可配置插件。
    @Test("disabled 策略插件不视为可配置插件")
    func disabledPolicyPluginIsNotConfigurable() throws {
        let settings = DefaultSettingViewProviding()
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any SettingViewProviding).self, settings)
        try kernel.registerProvider(
            (any PluginManaging).self,
            DefaultPluginManager(kernel: kernel)
        )

        let plugin = PluginPluginManager()
        try kernel.start(plugins: [
            plugin,
            TestPlugin(id: "turned-off", policy: .disabled),
        ])

        #expect(!settings.entries.contains { $0.id == "plugin-manager" })
    }

    /// 入口不存在时，「浏览插件」提示建议也要撤掉。
    ///
    /// 这条守卫盯住「深链指向不存在的设置页」这个坑：提示建议的动作是
    /// `openSettingsTab("plugin-manager")`，入口被撤掉后这个深链就是死路。
    @Test("入口不存在时不注册浏览插件提示建议")
    func doesNotRegisterPromptSuggestionWithoutEntry() throws {
        let settings = DefaultSettingViewProviding()
        let suggestions = DefaultPromptSuggestionProvider()
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any SettingViewProviding).self, settings)
        try kernel.registerProvider((any PromptSuggestionProviding).self, suggestions)
        try kernel.registerProvider(
            (any PluginManaging).self,
            DefaultPluginManager(kernel: kernel)
        )

        let plugin = PluginPluginManager()
        try kernel.start(plugins: [plugin])
        #expect(!settings.entries.contains { $0.id == "plugin-manager" })
        #expect(!suggestions.allSuggestions.contains { $0.id == "\(plugin.id).browse" })
    }

    /// 入口存在时，「浏览插件」提示建议注册并指向该入口。
    @Test("入口存在时注册浏览插件提示建议")
    func registersPromptSuggestionWithEntry() throws {
        let settings = DefaultSettingViewProviding()
        let suggestions = DefaultPromptSuggestionProvider()
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any SettingViewProviding).self, settings)
        try kernel.registerProvider((any PromptSuggestionProviding).self, suggestions)
        try kernel.registerProvider(
            (any PluginManaging).self,
            DefaultPluginManager(kernel: kernel)
        )

        let plugin = PluginPluginManager()
        try kernel.start(plugins: [
            plugin,
            TestPlugin(id: "optional", policy: .enabledByDefault),
        ])

        let suggestion = suggestions.allSuggestions.first { $0.id == "\(plugin.id).browse" }
        #expect(suggestion != nil)
        #expect(suggestion?.action == .openSettingsTab(PluginPluginManager.settingsEntryID))
    }
}

@MainActor
private final class TestPlugin: SuperPlugin {
    let id: String
    let order: Int
    let metadata: PluginMetadata

    init(id: String, policy: PluginEnablePolicy, order: Int = 999) {
        self.id = id
        self.order = order
        metadata = PluginMetadata(
            id: id,
            name: id,
            policy: policy
        )
    }
}
