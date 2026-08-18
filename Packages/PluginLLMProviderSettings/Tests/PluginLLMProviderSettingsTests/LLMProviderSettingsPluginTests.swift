import Foundation
import KernelCore
import KitLLM
import ProviderLLMManager
import ProviderSettingView
import Testing
@testable import PluginLLMProviderSettings

@MainActor
struct LLMProviderSettingsPluginTests {

    /// 测试用最小供应商（远程，可配 API Key）。
    @MainActor
    private final class MockRemoteProvider: ManagedLLMProvider, @preconcurrency LLMProviding {
        let providerInfo: LLMProviderInfo
        private var storedKey: String = ""

        init(id: String, displayName: String) {
            providerInfo = LLMProviderInfo(
                id: id,
                displayName: displayName,
                defaultModel: "model-a",
                models: [LLMModelInfo(id: "model-a"), LLMModelInfo(id: "model-b")],
                apiKeyStorageKey: "test.\(id)"
            )
        }

        var providerID: String { providerInfo.id }
        func complete(_ request: LLMRequest) async throws -> LLMResponse {
            LLMResponse(content: "mock", model: request.model)
        }
        func hasApiKey() -> Bool { !storedKey.isEmpty }
        func getApiKey() -> String { storedKey }
        func setApiKey(_ apiKey: String) { storedKey = apiKey }
        func removeApiKey() { storedKey = "" }
    }

    @Test("onBoot 注册云端/本地两个设置入口")
    func pluginRegistersSettingEntries() throws {
        let kernel = KernelCoreContainer()
        let settings = DefaultSettingViewProviding()
        let manager = DefaultLLMProviderManagerProviding()
        try kernel.registerProvider((any SettingViewProviding).self, settings)
        try kernel.registerProvider((any LLMProviderManagerProviding).self, manager)

        let plugin = LLMProviderSettingsPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(settings.entries.count == 2)
        #expect(settings.entries.contains(where: { $0.id == "\(plugin.id).remote-providers" }))
        #expect(settings.entries.contains(where: { $0.id == "\(plugin.id).local-providers" }))

        // 详情视图可渲染（不崩溃）。
        for entry in settings.entries {
            #expect(entry.makeDetailView() != nil)
        }
    }

    @Test("onShutdown 撤回设置入口")
    func pluginShutdownRemovesEntries() throws {
        let kernel = KernelCoreContainer()
        let settings = DefaultSettingViewProviding()
        let manager = DefaultLLMProviderManagerProviding()
        try kernel.registerProvider((any SettingViewProviding).self, settings)
        try kernel.registerProvider((any LLMProviderManagerProviding).self, manager)

        let plugin = LLMProviderSettingsPlugin()
        try plugin.onBoot(kernel: kernel)
        try plugin.onShutdown(kernel: kernel)

        #expect(settings.entries.isEmpty)
    }

    @Test("无管理器时 onBoot 静默跳过")
    func pluginBootWithoutManagerIsNoop() throws {
        let kernel = KernelCoreContainer()
        let settings = DefaultSettingViewProviding()
        try kernel.registerProvider((any SettingViewProviding).self, settings)

        let plugin = LLMProviderSettingsPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(settings.entries.isEmpty)
    }

    @Test("设置页数据源来自管理器注册表")
    func settingsPageReadsManagerRegistry() throws {
        let manager = DefaultLLMProviderManagerProviding()
        try manager.register(MockRemoteProvider(id: "p1", displayName: "Provider One"))
        try manager.register(MockRemoteProvider(id: "p2", displayName: "Provider Two"))

        #expect(manager.allProviders().count == 2)
        #expect(manager.provider(id: "p1")?.providerInfo.displayName == "Provider One")
        #expect(manager.models(for: "p1") == ["model-a", "model-b"])
    }
}
