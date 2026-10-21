import Foundation
import KernelCore
import ProviderDocsView
import ProviderStorage
import Testing
@testable import TextActionsPlugin

// MARK: - 临时目录助手

/// 为每个用例提供独立的临时目录。
private struct TempDirectory {
    let url: URL

    init() {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("TextActionsTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - 插件生命周期

@Suite("Text Actions 插件生命周期", .serialized)
@MainActor
struct TextActionsPluginLifecycleTests {

    @Test("注册时写入关于与说明书文档条目")
    func registerAddsDocsEntries() throws {
        let kernel = KernelCoreContainer()
        let docs = DefaultDocsViewProviding()
        try kernel.registerProvider((any DocsViewProviding).self, docs)

        let plugin = TextActionsPlugin()
        try plugin.onRegister(kernel: kernel)

        #expect(docs.aboutEntries.map(\.id) == [plugin.id])
        #expect(docs.manualEntries.map(\.id) == [plugin.id])
        #expect(docs.aboutEntries.first?.name == plugin.metadata.name)
    }

    @Test("缺少文档 Provider 时注册不抛错")
    func registerWithoutDocsProviderIsNoop() throws {
        let kernel = KernelCoreContainer()

        try TextActionsPlugin().onRegister(kernel: kernel)
    }

    @Test("启动时把存储目录注入运行时")
    func bootInjectsStorageDirectory() throws {
        let temp = TempDirectory()
        defer {
            TextActionsRuntime.reset()
            temp.cleanup()
        }
        let kernel = KernelCoreContainer()
        let storage = DefaultStorageProvider(dataRootDirectory: temp.url)
        try kernel.registerProvider((any StorageProviding).self, storage)

        let plugin = TextActionsPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(TextActionsRuntime.settingsDirectory() == storage.pluginDataDirectory(for: plugin.id))
    }

    @Test("缺少存储 Provider 时启动不抛错")
    func bootWithoutStorageProviderIsNoop() throws {
        let kernel = KernelCoreContainer()

        try TextActionsPlugin().onBoot(kernel: kernel)
    }

    @Test("关闭时移除设置入口并清理观察者")
    func shutdownCleansUp() throws {
        let kernel = KernelCoreContainer()

        let plugin = TextActionsPlugin()
        try plugin.onBoot(kernel: kernel)
        try plugin.onShutdown(kernel: kernel)
    }

    @Test("注销时移除文档条目")
    func unregisterRemovesDocsEntries() throws {
        let kernel = KernelCoreContainer()
        let docs = DefaultDocsViewProviding()
        try kernel.registerProvider((any DocsViewProviding).self, docs)

        let plugin = TextActionsPlugin()
        try plugin.onRegister(kernel: kernel)
        try plugin.onUnregister(kernel: kernel)

        #expect(docs.aboutEntries.isEmpty)
        #expect(docs.manualEntries.isEmpty)
    }

    @Test("插件元数据保持稳定")
    func pluginMetadataIsStable() {
        let plugin = TextActionsPlugin()

        #expect(plugin.id == "com.coffic.lumi.plugin.text-actions")
        #expect(plugin.order == 275)
        #expect(plugin.metadata.policy == .disabledByDefault)
        #expect(plugin.legacyDataDirectoryNames.isEmpty)
    }
}

// MARK: - 数据迁移

@Suite("Text Actions 数据迁移", .serialized)
@MainActor
struct TextActionsPluginMigrationTests {

    private static let legacyKey = "TextActions.enabled"

    /// 注入假域，替换测试进程里取不到的 app 持久化域。
    private func withLegacyDomain(_ domain: [String: Any]?, _ body: () throws -> Void) rethrows {
        let previous = TextActionsPlugin.legacyDefaultsDomainProvider
        TextActionsPlugin.legacyDefaultsDomainProvider = { domain }
        defer { TextActionsPlugin.legacyDefaultsDomainProvider = previous }
        try body()
    }

    private func makeContext(root: URL, pluginID: String) -> PluginDataMigrationContext {
        PluginDataMigrationContext(
            pluginID: pluginID,
            currentMajorVersion: 6,
            currentDataRootDirectory: root,
            legacyDataRootDirectories: [:]
        )
    }

    @Test("没有旧开关时不做任何导入")
    func skipsWhenNoLegacyValue() throws {
        let temp = TempDirectory()
        defer { temp.cleanup() }
        let plugin = TextActionsPlugin()

        try withLegacyDomain([:]) {
            try plugin.migrateData(context: makeContext(root: temp.url, pluginID: plugin.id))
        }

        let store = TextActionsPluginLocalStore(settingsDirectory: temp.url.appendingPathComponent(plugin.id))
        #expect(store.object(forKey: Self.legacyKey) == nil)
    }

    @Test("取不到旧域时不做任何导入")
    func skipsWhenDomainUnavailable() throws {
        let temp = TempDirectory()
        defer { temp.cleanup() }
        let plugin = TextActionsPlugin()

        try withLegacyDomain(nil) {
            try plugin.migrateData(context: makeContext(root: temp.url, pluginID: plugin.id))
        }

        let store = TextActionsPluginLocalStore(settingsDirectory: temp.url.appendingPathComponent(plugin.id))
        #expect(store.object(forKey: Self.legacyKey) == nil)
    }

    @Test("旧开关被导入插件专属存储")
    func importsLegacyValue() throws {
        let temp = TempDirectory()
        defer { temp.cleanup() }
        let plugin = TextActionsPlugin()

        try withLegacyDomain([Self.legacyKey: true]) {
            try plugin.migrateData(context: makeContext(root: temp.url, pluginID: plugin.id))
        }

        let store = TextActionsPluginLocalStore(settingsDirectory: temp.url.appendingPathComponent(plugin.id))
        #expect(store.bool(forKey: Self.legacyKey))
    }

    @Test("存储已有值时不被旧开关覆盖")
    func doesNotOverwriteExistingValue() throws {
        let temp = TempDirectory()
        defer { temp.cleanup() }
        let plugin = TextActionsPlugin()
        let directory = temp.url.appendingPathComponent(plugin.id)
        let store = TextActionsPluginLocalStore(settingsDirectory: directory)
        store.set(false, forKey: Self.legacyKey)

        try withLegacyDomain([Self.legacyKey: true]) {
            try plugin.migrateData(context: makeContext(root: temp.url, pluginID: plugin.id))
        }

        #expect(store.bool(forKey: Self.legacyKey) == false)
    }
}
