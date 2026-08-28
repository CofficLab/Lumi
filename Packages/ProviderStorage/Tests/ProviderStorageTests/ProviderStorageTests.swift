import Foundation
import KernelCore
import Testing
@testable import ProviderStorage

/// StorageProviding 协议与默认实现的基础验证。
///
/// 默认实现的磁盘布局必须与旧版 StoragePlugin 完全一致：
/// - 数据根目录：`~/Library/Application Support/<bundleID>/db_<debug|production>_v<majorVersion>/`
/// - 插件数据目录：`<root>/<pluginID>/`（无 `Plugins/` 中间层）
/// - 核心数据目录：`<root>/Core/`
@Suite("ProviderStorage")
@MainActor
struct ProviderStorageTests {

    /// 用临时目录创建默认实现，避免污染真实 Application Support。
    private func makeProvider() -> DefaultStorageProvider {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProviderStorageTests-\(UUID().uuidString)", isDirectory: true)
        return DefaultStorageProvider(dataRootDirectory: tempRoot)
    }

    @Test("数据根目录存在")
    func dataRootDirectoryExists() {
        let provider = makeProvider()
        let root = provider.dataRootDirectory

        #expect(FileManager.default.fileExists(atPath: root.path))
    }

    @Test("插件数据目录直接挂在根目录下，不带 Plugins 中间层（与旧版一致）")
    func pluginDataDirectoryCreated() {
        let provider = makeProvider()
        let dir = provider.pluginDataDirectory(for: "com.example.plugin")

        #expect(!dir.pathComponents.contains("Plugins"))
        #expect(dir.pathComponents.contains("com.example.plugin"))
        #expect(FileManager.default.fileExists(atPath: dir.path))
    }

    @Test("不同插件目录相互独立")
    func pluginDirectoriesAreDistinct() {
        let provider = makeProvider()
        let a = provider.pluginDataDirectory(for: "plugin.a")
        let b = provider.pluginDataDirectory(for: "plugin.b")

        #expect(a.path != b.path)
    }

    @Test("核心数据目录已创建")
    func coreDataDirectoryCreated() {
        let provider = makeProvider()
        let dir = provider.coreDataDirectory()

        #expect(dir.pathComponents.contains("Core"))
        #expect(FileManager.default.fileExists(atPath: dir.path))
    }

    @Test("StorageProviding 可作为 any StorageProviding 使用")
    func providerAccessibleThroughProtocol() {
        let provider: any StorageProviding = makeProvider()

        let dir = provider.pluginDataDirectory(for: "test.plugin")

        #expect(FileManager.default.fileExists(atPath: dir.path))
    }

    // MARK: - 旧版命名规则

    @Test("数据根目录名遵循 db_<debug|production>_v<major> 规则")
    func dataRootDirectoryNaming() {
        #expect(DefaultStorageProvider.dataRootDirectoryName(debug: true, majorVersion: 5) == "db_debug_v5")
        #expect(DefaultStorageProvider.dataRootDirectoryName(debug: false, majorVersion: 5) == "db_production_v5")
        #expect(DefaultStorageProvider.dataRootDirectoryName(debug: false, majorVersion: 4) == "db_production_v4")
    }

    @Test("主版本号解析：取版本号第一段，无法解析回退 4")
    func majorVersionParsing() {
        #expect(DefaultStorageProvider.majorVersion(from: "5.3.1") == 5)
        #expect(DefaultStorageProvider.majorVersion(from: "6") == 6)
        #expect(DefaultStorageProvider.majorVersion(from: "abc") == 4)
        #expect(DefaultStorageProvider.majorVersion(from: "") == 4)
    }

    // MARK: - PluginEnabledStateStore（原目录持久化）

    /// 用临时目录构建插件数据目录下的 store。
    private func makeStore() -> PluginEnabledStateStore {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginEnabledStateStoreTests-\(UUID().uuidString)", isDirectory: true)
        // 与旧版一致：数据目录名固定为 "PluginManager"，保证文件落在原目录。
        let dir = DefaultStorageProvider(dataRootDirectory: tempRoot)
            .pluginDataDirectory(for: "PluginManager")
        return PluginEnabledStateStore(pluginDirectory: dir)
    }

    @Test("未写入时返回 nil")
    func initiallyEmpty() {
        let store = makeStore()
        #expect(store.enabledState(pluginID: "com.example.plugin") == nil)
    }

    @Test("写入后能读取，且落盘到原目录 plist")
    func persistAndReload() {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginEnabledStateStoreReload-\(UUID().uuidString)", isDirectory: true)
        let dir = DefaultStorageProvider(dataRootDirectory: tempRoot)
            .pluginDataDirectory(for: "PluginManager")
        let store = PluginEnabledStateStore(pluginDirectory: dir)
        store.setEnabled(false, pluginID: "com.example.plugin")

        // 文件应写入 <root>/PluginManager/plugin-enabled-overrides.plist（原目录 + 原名）。
        let fileURL = dir.appendingPathComponent("plugin-enabled-overrides.plist", isDirectory: false)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        // 新实例重新加载同一目录，能读到之前的覆盖状态（模拟重启）。
        let reloaded = PluginEnabledStateStore(pluginDirectory: dir)
        #expect(reloaded.enabledState(pluginID: "com.example.plugin") == false)
    }

    @Test("内核启停状态跨内核实例持久化")
    func kernelPersistsEnabledStateAcrossInstances() async throws {
        final class ConfigurablePlugin: SuperPlugin {
            let id: String
            let metadata: PluginMetadata

            init(id: String) {
                self.id = id
                self.metadata = PluginMetadata(id: id, policy: .enabledByDefault)
            }
        }

        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("KernelPluginStateTests-\(UUID().uuidString)", isDirectory: true)
        let storage = DefaultStorageProvider(dataRootDirectory: tempRoot)
        let pluginDirectory = storage.pluginDataDirectory(for: "PluginManager")
        let pluginID = "com.example.persisted-plugin"

        let kernel = KernelCoreContainer()
        kernel.stateStore = PluginEnabledStateStore(pluginDirectory: pluginDirectory)
        try kernel.start(plugins: [ConfigurablePlugin(id: pluginID)])
        #expect(kernel.isPluginEnabled(id: pluginID))

        try await kernel.disablePlugin(id: pluginID)
        #expect(!kernel.isPluginEnabled(id: pluginID))

        let reloadedKernel = KernelCoreContainer()
        reloadedKernel.stateStore = PluginEnabledStateStore(pluginDirectory: pluginDirectory)
        try reloadedKernel.start(plugins: [ConfigurablePlugin(id: pluginID)])
        #expect(!reloadedKernel.isPluginEnabled(id: pluginID))

        try await reloadedKernel.enablePlugin(id: pluginID)
        #expect(reloadedKernel.isPluginEnabled(id: pluginID))
    }

    @Test("必需插件忽略持久化禁用状态")
    func requiredPluginIgnoresPersistedDisabledState() throws {
        final class RequiredPlugin: SuperPlugin {
            let id = "com.example.required-plugin"
            let metadata = PluginMetadata(
                id: "com.example.required-plugin",
                policy: .required
            )
        }

        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("KernelPluginPolicyTests-\(UUID().uuidString)", isDirectory: true)
        let storage = DefaultStorageProvider(dataRootDirectory: tempRoot)
        let store = PluginEnabledStateStore(
            pluginDirectory: storage.pluginDataDirectory(for: "PluginManager")
        )
        store.setEnabled(false, pluginID: "com.example.required-plugin")

        let kernel = KernelCoreContainer()
        kernel.stateStore = store
        try kernel.start(plugins: [RequiredPlugin()])

        #expect(kernel.isPluginEnabled(id: "com.example.required-plugin"))
    }

    @Test("删除状态后回落为 nil")
    func removeStateClears() {
        let store = makeStore()
        store.setEnabled(true, pluginID: "com.example.plugin")
        #expect(store.enabledState(pluginID: "com.example.plugin") == true)

        store.removeState(pluginID: "com.example.plugin")
        #expect(store.enabledState(pluginID: "com.example.plugin") == nil)
    }

}
