import Testing
import Foundation
import KernelCore
import KitTestSupport
import ProviderActivityBar
import ProviderChatSection
import ProviderContentView
import ProviderRailView
import ProviderRootView
import ProviderSettingView
import ProviderStorage
import ProviderToolbar
@testable import PluginAppStoreConnect

/// 测试用存储 Provider：根落在临时目录，插件目录按 pluginID 分目录。
///
/// 插件 `onBoot` 会解析 `StorageProviding` 并注入运行时目录；测试进程下
/// 目录守卫拒绝回退到本机真实数据目录，因此必须显式提供一个临时根。
private final class TestStorageProvider: StorageProviding {
    let dataRootDirectory: URL

    init() {
        dataRootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginAppStoreConnectTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dataRootDirectory, withIntermediateDirectories: true)
    }

    func pluginDataDirectory(for pluginID: String) -> URL {
        let directory = dataRootDirectory.appendingPathComponent(pluginID, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    func coreDataDirectory() -> URL {
        let directory = dataRootDirectory.appendingPathComponent("Core", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

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
    try kernel.registerProvider((any StorageProviding).self, TestStorageProvider())

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
    try kernel.registerProvider((any RootViewProviding).self, DefaultRootViewProviding())
    try kernel.registerProvider((any ToolbarProviding).self, toolbar)
    try kernel.registerProvider((any StorageProviding).self, TestStorageProvider())

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

    #expect(names.count == 27)
    #expect(Set(names).count == names.count)
    #expect(names.allSatisfy { $0.hasPrefix("app_store_connect_") })
    #expect(names.allSatisfy { !$0.contains("-") && !$0.contains(".") })
}

@Test("schemas expose object roots")
@MainActor
func toolSchemasAreObjects() {
    let schemas = AppStoreConnectPlugin.agentTools.map { $0.inputSchema(for: .english) }
    #expect(schemas.count == 27)
    #expect(schemas.allSatisfy { ($0["type"] as? String) == "object" })
}

@Test("delete version tool is a high-risk single-id operation")
@MainActor
func deleteVersionToolShape() {
    let tool = DeleteAppStoreConnectVersionTool()

    #expect(tool.name == "app_store_connect_delete_version")
    #expect(tool.permissionRiskLevel(arguments: [:]) == .high)
    let properties = tool.inputSchema(for: .english)["properties"] as? [String: Any]
    #expect(properties?["versionID"] != nil)
}

@Test("update version exposes earliestReleaseDate alongside existing fields")
@MainActor
func updateVersionSchemaIncludesEarliestReleaseDate() {
    let tool = UpdateAppStoreConnectVersionTool()

    let properties = tool.inputSchema(for: .english)["properties"] as? [String: Any]
    #expect(properties?["copyright"] != nil)
    #expect(properties?["releaseType"] != nil)
    #expect(properties?["downloadable"] != nil)
    #expect(properties?["earliestReleaseDate"] != nil)
}

@Test("credentials require all App Store Connect signing fields")
func credentialsCompleteness() {
    #expect(!AppStoreConnectCredentials(issuerID: "", keyID: "key", privateKey: "pem").isComplete)
    #expect(!AppStoreConnectCredentials(issuerID: "issuer", keyID: "", privateKey: "pem").isComplete)
    #expect(!AppStoreConnectCredentials(issuerID: "issuer", keyID: "key", privateKey: "").isComplete)
    #expect(AppStoreConnectCredentials(issuerID: "issuer", keyID: "key", privateKey: "pem").isComplete)
}
