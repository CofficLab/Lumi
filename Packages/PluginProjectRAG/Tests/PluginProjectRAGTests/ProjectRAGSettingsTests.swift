import Foundation
@testable import PluginProjectRAG
import KernelCore
import ProjectRAGEngine
import ProviderSettingView
import ProviderStorage
import Testing

@Suite("ProjectRAGSettings")
@MainActor
struct ProjectRAGSettingsTests {
    private func makeDefaults() -> UserDefaults {
        let suite = "rag-settings-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private func makeService() -> RAGService {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-settings-\(UUID().uuidString)", isDirectory: true)
        return RAGService(databaseDirectoryProvider: { directory })
    }

    @Test("自动注入默认开启")
    func autoInjectDefaultsToEnabled() {
        let viewModel = ProjectRAGSettingsViewModel(service: makeService(), defaults: makeDefaults())
        #expect(viewModel.autoInjectEnabled)
    }

    @Test("自动注入开关必须写入 Hook 读取的同一 key")
    func autoInjectTogglePersistsToPolicyKey() {
        let defaults = makeDefaults()
        let viewModel = ProjectRAGSettingsViewModel(service: makeService(), defaults: defaults)
        viewModel.autoInjectEnabled = false
        #expect(defaults.object(forKey: RAGInjectionPolicy.autoInjectEnabledKey) as? Bool == false)
        let reloaded = ProjectRAGSettingsViewModel(service: makeService(), defaults: defaults)
        #expect(reloaded.autoInjectEnabled == false)
    }

    @Test("暂停开关驱动 RAGService 并回读真实状态")
    func pauseToggleDrivesService() async {
        let service = makeService()
        let viewModel = ProjectRAGSettingsViewModel(service: service, defaults: makeDefaults())
        await viewModel.setIndexingPaused(true)
        #expect(viewModel.indexingPaused)
        #expect(await service.isIndexingPaused())
        await viewModel.setIndexingPaused(false)
        #expect(viewModel.indexingPaused == false)
        #expect(await service.isIndexingPaused() == false)
    }

    @Test("load 反映外部设置的暂停状态")
    func loadReflectsServiceState() async {
        let service = makeService()
        await service.setIndexingPaused(true)
        let viewModel = ProjectRAGSettingsViewModel(service: service, defaults: makeDefaults())
        await viewModel.load()
        #expect(viewModel.indexingPaused)
    }

    @Test("boot 注册设置入口，shutdown 必须撤回")
    func settingsEntryLifecycle() throws {
        let kernel = KernelCoreContainer()
        let settings = DefaultSettingViewProviding()
        try kernel.registerProvider((any SettingViewProviding).self, settings)
        // 注入**独立**的存储目录：否则回退到共享的临时目录 → 共用同一个
        // `rag.sqlite` → 多个用例的 initialize 互相等待 → 高负载下偶发超时。
        let storageRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-settings-\(UUID().uuidString)", isDirectory: true)
        try kernel.registerProvider(
            (any StorageProviding).self,
            StubStorageProvider(root: storageRoot)
        )
        defer { try? FileManager.default.removeItem(at: storageRoot) }
        let plugin = ProjectRAGPlugin()

        try plugin.onBoot(kernel: kernel)
        #expect(settings.entries.contains { $0.id == "\(plugin.id).settings" })

        try plugin.onShutdown(kernel: kernel)
        #expect(!settings.entries.contains { $0.id == "\(plugin.id).settings" })
    }
}