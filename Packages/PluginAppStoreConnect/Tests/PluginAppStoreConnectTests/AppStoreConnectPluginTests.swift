import Testing
import KernelCore
import ProviderActivityBar
import ProviderChatSection
import ProviderContentView
import ProviderRailView
import ProviderRootView
import ProviderSettingView
import ProviderToolbar
@testable import PluginAppStoreConnect

@Test("plugin metadata follows the current integration conventions")
@MainActor
func pluginMetadata() {
    let plugin = AppStoreConnectPlugin()

    #expect(plugin.id == "com.coffic.lumi.plugin.app-store-connect")
    #expect(plugin.metadata.id == plugin.id)
    #expect(plugin.metadata.category == .integration)
    #expect(plugin.metadata.stage == .preview)
    #expect(plugin.metadata.policy == .disabledByDefault)
    #expect(AppStoreConnectPlugin.railTabID == "app-store-connect.sidebar")
    #expect(AppStoreConnectPlugin.settingsEntryID == "com.coffic.lumi.plugin.app-store-connect.settings")
}

@Test("plugin contributes its API configuration to Settings")
@MainActor
func settingsEntry() throws {
    let kernel = KernelCoreContainer()
    let settings = DefaultSettingViewProviding()
    try kernel.registerProvider((any SettingViewProviding).self, settings)

    let plugin = AppStoreConnectPlugin()
    try plugin.onBoot(kernel: kernel)

    #expect(settings.entries.contains(where: { $0.id == AppStoreConnectPlugin.settingsEntryID }))

    try plugin.onShutdown(kernel: kernel)
    #expect(!settings.entries.contains(where: { $0.id == AppStoreConnectPlugin.settingsEntryID }))
}

@Test("activating the plugin keeps chat toolbar items visible")
@MainActor
func activationKeepsChatToolbarCategoryVisible() throws {
    let kernel = KernelCoreContainer()
    let activity = DefaultActivityBarProviding()
    let chat = DefaultChatSectionProviding()
    let toolbar = DefaultToolbarProviding()

    try kernel.registerProvider((any ActivityBarProviding).self, activity)
    try kernel.registerProvider((any ChatSectionProviding).self, chat)
    try kernel.registerProvider((any ContentViewProviding).self, DefaultContentViewProviding())
    try kernel.registerProvider((any RailViewProviding).self, DefaultRailViewProviding())
    try kernel.registerProvider((any RootViewProviding).self, DefaultRootViewProvider())
    try kernel.registerProvider((any ToolbarProviding).self, toolbar)

    let plugin = AppStoreConnectPlugin()
    try plugin.onBoot(kernel: kernel)

    #expect(activity.activeItemID == "com.coffic.lumi.plugin.app-store-connect.entry")
    // 插件工作区复用了 Chat 区块，因此必须保留 `.chat` 分类，
    // 否则新建对话 / 会话列表等对话工具栏项会被过滤掉。
    #expect(toolbar.visibleCategories.contains(.chat))
    #expect(toolbar.visibleCategories.contains(.global))
    #expect(chat.isVisible)

    try plugin.onShutdown(kernel: kernel)
}

@Test("plugin loads its App Store Connect skill from bundled resources")
func appStoreConnectSkill() {
    let skills = AppStoreConnectSkillContributor().allSkills

    #expect(skills.count == 1)
    #expect(skills.first?.name == "app-store-connect")
    #expect(skills.first?.loadContent()?.contains("app_store_connect_create_version") == true)
}

@Test("all restored agent tools use unique current names")
@MainActor
func toolNamesUseCurrentConvention() {
    let names = AppStoreConnectPlugin.agentTools.map(\.name)

    #expect(names.count == 24)
    #expect(Set(names).count == names.count)
    #expect(names.allSatisfy { $0.hasPrefix("app_store_connect_") })
    #expect(names.allSatisfy { !$0.contains("-") && !$0.contains(".") })
}

@Test("schemas expose object roots")
@MainActor
func toolSchemasAreObjects() {
    let schemas = AppStoreConnectPlugin.agentTools.map { $0.inputSchema(for: .english) }
    #expect(schemas.count == 24)
    #expect(schemas.allSatisfy { ($0["type"] as? String) == "object" })
}

@Test("credentials require all App Store Connect signing fields")
func credentialsCompleteness() {
    #expect(!AppStoreConnectCredentials(issuerID: "", keyID: "key", privateKey: "pem").isComplete)
    #expect(!AppStoreConnectCredentials(issuerID: "issuer", keyID: "", privateKey: "pem").isComplete)
    #expect(!AppStoreConnectCredentials(issuerID: "issuer", keyID: "key", privateKey: "").isComplete)
    #expect(AppStoreConnectCredentials(issuerID: "issuer", keyID: "key", privateKey: "pem").isComplete)
}
