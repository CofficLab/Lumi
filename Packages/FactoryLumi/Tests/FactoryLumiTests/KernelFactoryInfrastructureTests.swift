import FactoryLumi
import KernelCore
import ProviderPluginControl
import ProviderPluginManaging
import ProviderWebServer
import ProviderChatSection
import ProviderStorage
import Testing

@Suite("FactoryLumi Infrastructure")
@MainActor
struct KernelFactoryInfrastructureTests {
    private final class MigrationProbePlugin: SuperPlugin, PluginDataMigrating {
        let id = "test.storage-migration-probe"
        let metadata = PluginMetadata(
            id: "test.storage-migration-probe",
            name: "Storage migration probe",
            description: "",
            category: .general,
            stage: .stable,
            policy: .alwaysOn
        )
        let legacyDataDirectoryNames = ["LegacyProbe"]
        var foundPayloadOnBoot = false

        func onBoot(kernel: KernelCoreContainer) throws {
            guard let storage = kernel.resolveProvider((any StorageProviding).self) else { return }
            foundPayloadOnBoot = FileManager.default.fileExists(
                atPath: storage.pluginDataDirectory(for: id)
                    .appendingPathComponent("payload.txt")
                    .path
            )
        }
    }

    private struct SinglePluginFactory: PluginFactory {
        let plugin: any SuperPlugin

        func makePlugins() -> [any SuperPlugin] { [plugin] }
    }
    private final class AsyncProbePlugin: AsyncSuperPlugin {
        let id = "test.async-probe"
        let metadata = PluginMetadata(
            id: "test.async-probe",
            name: "Async probe",
            description: "",
            category: .general,
            stage: .stable,
            policy: .alwaysOn
        )
        var didBoot = false
        var didBecomeReady = false

        func onBootAsync(kernel: KernelCoreContainer) async throws {
            await Task.yield()
            didBoot = true
        }

        func onReadyAsync(kernel: KernelCoreContainer) async throws {
            await Task.yield()
            didBecomeReady = true
        }
    }

    @Test("异步 Factory 入口启动异步插件")
    func startsAsyncPlugins() async throws {
        let probe = AsyncProbePlugin()
        let kernel = try await KernelFactory.makeKernelAsync(additionalPlugins: [probe])

        #expect(probe.didBoot)
        #expect(probe.didBecomeReady)
        #expect(kernel.isPluginRegistered(id: probe.id))
        #expect(kernel.lifecycleState == .running)
    }

    @Test("KernelFactory 在插件启动前迁移全部旧版本目录")
    func migratesPluginDataBeforeBoot() throws {
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("FactoryLumiMigration-\(UUID().uuidString)", isDirectory: true)
        let currentRoot = parent.appendingPathComponent("db_production_v6", isDirectory: true)
        let previousRoot = parent.appendingPathComponent("db_production_v5", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: parent) }

        let plugin = MigrationProbePlugin()
        try FileManager.default.createDirectory(
            at: previousRoot.appendingPathComponent(plugin.id, isDirectory: true),
            withIntermediateDirectories: true
        )
        try Data("same-id".utf8).write(
            to: previousRoot.appendingPathComponent(plugin.id, isDirectory: true)
                .appendingPathComponent("payload.txt")
        )
        try FileManager.default.createDirectory(
            at: previousRoot.appendingPathComponent("LegacyProbe", isDirectory: true),
            withIntermediateDirectories: true
        )
        try Data("legacy-name".utf8).write(
            to: previousRoot.appendingPathComponent("LegacyProbe", isDirectory: true)
                .appendingPathComponent("legacy.txt")
        )

        _ = try KernelFactory.makeKernel(
            providerFactory: DefaultProviderFactory(dataRootDirectory: currentRoot),
            pluginFactory: SinglePluginFactory(plugin: plugin)
        )

        let destination = currentRoot.appendingPathComponent(plugin.id, isDirectory: true)
        #expect(plugin.foundPayloadOnBoot)
        #expect(FileManager.default.fileExists(atPath: destination.appendingPathComponent("payload.txt").path))
        #expect(FileManager.default.fileExists(atPath: destination.appendingPathComponent("legacy.txt").path))
        #expect(FileManager.default.fileExists(atPath: previousRoot.appendingPathComponent("LegacyProbe/legacy.txt").path))
    }

    @Test("Factory 注册可替换 WebServer 与真实 PluginControl")
    func registersInfrastructureProviders() throws {
        let kernel = try KernelFactory.makeKernel()

        #expect(kernel.resolveProvider((any WebServerProviding).self) != nil)
        #expect(kernel.resolveProvider((any PluginControlling).self) != nil)
        let managing = kernel.resolveProvider((any PluginManaging).self)
        #expect(managing != nil)
        #expect(managing?.pluginCount == kernel.registeredPluginCount)
        #expect(managing?.isRegistered(id: "com.coffic.lumi.plugin.plugin-manager") == true)
        let chat = kernel.resolveProvider((any ChatSectionProviding).self)
        #expect(chat?.isVisible == true)
        #expect(chat?.isContextActive == true)
    }
}
