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
    private final class MockRemoteProvider: ManagedLLMProvider {
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
        try kernel.registerProvider((any LLMManaging).self, manager)

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
        try kernel.registerProvider((any LLMManaging).self, manager)

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

    @Test("自定义供应商保存后可恢复并自动注册")
    func customProviderPersistsAndRestores() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-custom-provider-\(UUID().uuidString)")
            .appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let configuration = UserDefinedCloudProviderConfiguration(
            id: "custom-openai",
            displayName: "团队网关",
            description: "内部 OpenAI 兼容服务",
            baseURL: "https://llm.example.com/v1",
            defaultModel: "team-model",
            models: [UserDefinedCloudModel(id: "team-model", supportsVision: true)],
            websiteURLString: "https://llm.example.com"
        )
        let manager = DefaultLLMProviderManagerProviding()
        let store = UserDefinedCloudProviderStore(fileURL: fileURL)
        store.attach(manager: manager, apiService: VendorAPIService())

        try store.upsert(configuration)

        #expect(store.configurations == [configuration])
        #expect(manager.provider(id: configuration.id) is UserDefinedCloudProvider)
        #expect(manager.models(for: configuration.id) == ["team-model"])
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        let restored = UserDefinedCloudProviderStore(fileURL: fileURL)
        #expect(restored.configurations == [configuration])
    }

    @Test("删除自定义供应商会注销运行时实例并更新磁盘配置")
    func removingCustomProviderUnregistersAndPersists() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-custom-provider-\(UUID().uuidString)")
            .appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let configuration = UserDefinedCloudProviderConfiguration(
            id: "custom-anthropic",
            displayName: "Anthropic 网关",
            baseURL: "https://llm.example.com",
            apiFormat: .anthropic,
            defaultModel: "claude-team",
            models: [UserDefinedCloudModel(id: "claude-team")]
        )
        let manager = DefaultLLMProviderManagerProviding()
        let store = UserDefinedCloudProviderStore(fileURL: fileURL)
        store.attach(manager: manager, apiService: VendorAPIService())
        try store.upsert(configuration)

        try store.remove(id: configuration.id)

        #expect(store.configurations.isEmpty)
        #expect(manager.provider(id: configuration.id) == nil)
        #expect(UserDefinedCloudProviderStore(fileURL: fileURL).configurations.isEmpty)
    }
}
