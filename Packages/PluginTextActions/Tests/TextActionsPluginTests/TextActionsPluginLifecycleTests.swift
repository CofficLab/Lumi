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
        // 划词是一个「装上就该能用」的功能，且失效时完全静默，
        // 因此插件必须默认启用，不能要求用户先手动开启。
        #expect(plugin.metadata.policy == .enabledByDefault)
        #expect(plugin.legacyDataDirectoryNames.isEmpty)
    }

    @Test("启动完成时（onReady）就启动选区监听")
    func readyStartsSelectionMonitoring() throws {
        // 回归测试：内核启动流程只调用 `onBoot` / `onReady`，**从不调用
        // `onEnable`**。若启动监听只挂在 `onEnable` 上，
        // 「插件已启用 → 重启 App → 划词」这条最常见的路径就永远不工作，
        // 且既不报错也不弹菜单。
        //
        // 注入替身来断言「有没有调用过 startMonitoring」，
        // 既不注册真实的全局事件监听，也不依赖本机的辅助功能授权状态。
        let temp = TempDirectory()
        defer {
            TextActionsRuntime.reset()
            temp.cleanup()
        }
        let kernel = KernelCoreContainer()
        let storage = DefaultStorageProvider(dataRootDirectory: temp.url)
        try kernel.registerProvider((any StorageProviding).self, storage)

        // 让插件自身开关处于「开」。
        let store = TextActionsPluginLocalStore(
            settingsDirectory: storage.pluginDataDirectory(for: TextActionsPlugin().id)
        )
        store.setEnabled(true)

        let monitor = RecordingSelectionMonitor()
        let plugin = TextActionsPlugin(selectionMonitor: monitor, isFeatureEnabled: { true })
        try plugin.onBoot(kernel: kernel)
        try plugin.onReady(kernel: kernel)

        #expect(monitor.startCount == 1)
        #expect(monitor.isMonitoring)
    }

    @Test("插件自身开关关闭时不启动监听")
    func readyDoesNotStartMonitoringWhenDisabled() throws {
        let temp = TempDirectory()
        defer {
            TextActionsRuntime.reset()
            temp.cleanup()
        }
        let kernel = KernelCoreContainer()
        let storage = DefaultStorageProvider(dataRootDirectory: temp.url)
        try kernel.registerProvider((any StorageProviding).self, storage)

        let store = TextActionsPluginLocalStore(
            settingsDirectory: storage.pluginDataDirectory(for: TextActionsPlugin().id)
        )
        store.setEnabled(false)

        let monitor = RecordingSelectionMonitor()
        let plugin = TextActionsPlugin(selectionMonitor: monitor, isFeatureEnabled: { false })
        try plugin.onBoot(kernel: kernel)
        try plugin.onReady(kernel: kernel)

        #expect(monitor.startCount == 0)
        #expect(!monitor.isMonitoring)
    }

    @Test("运行时重新启用会启动监听")
    func enableStartsSelectionMonitoring() async throws {
        let temp = TempDirectory()
        defer {
            TextActionsRuntime.reset()
            temp.cleanup()
        }
        let kernel = KernelCoreContainer()
        let storage = DefaultStorageProvider(dataRootDirectory: temp.url)
        try kernel.registerProvider((any StorageProviding).self, storage)

        let store = TextActionsPluginLocalStore(
            settingsDirectory: storage.pluginDataDirectory(for: TextActionsPlugin().id)
        )
        store.setEnabled(true)

        let monitor = RecordingSelectionMonitor()
        let plugin = TextActionsPlugin(selectionMonitor: monitor, isFeatureEnabled: { true })
        try plugin.onBoot(kernel: kernel)
        try await plugin.onEnable(kernel: kernel)

        #expect(monitor.startCount == 1)
    }

    @Test("停用与关闭会停止监听")
    func disableAndShutdownStopSelectionMonitoring() async throws {
        let temp = TempDirectory()
        defer {
            TextActionsRuntime.reset()
            temp.cleanup()
        }
        let kernel = KernelCoreContainer()
        let storage = DefaultStorageProvider(dataRootDirectory: temp.url)
        try kernel.registerProvider((any StorageProviding).self, storage)

        let monitor = RecordingSelectionMonitor()
        let plugin = TextActionsPlugin(selectionMonitor: monitor, isFeatureEnabled: { true })
        try plugin.onBoot(kernel: kernel)

        try await plugin.onDisable(kernel: kernel)
        #expect(monitor.stopCount == 1)

        try plugin.onShutdown(kernel: kernel)
        #expect(monitor.stopCount == 2)
    }
}

// MARK: - 测试替身

/// 记录启停调用的选区监听替身。
///
/// - Note: 不注册真实的全局事件监听，也不读辅助功能授权——
///   这个用例要断言的是「插件有没有去启动监听」，
///   而不是「监听在真实环境下能不能跑起来」。
@MainActor
private final class RecordingSelectionMonitor: TextSelectionMonitoring {
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var isMonitoring = false

    func startMonitoring() {
        startCount += 1
        isMonitoring = true
    }

    func stopMonitoring() {
        stopCount += 1
        isMonitoring = false
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
