import Foundation
import KitLLM
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderSettings

/// 用户自定义云端供应商 Store 的落盘、注册与失败回滚行为。
///
/// 这是「添加供应商」真正落地的位置：界面提交后，
/// 配置要写进磁盘、供应商要注册进运行时管理器、两者任一失败都要能回滚。
@MainActor
struct UserDefinedCloudProviderStoreTests {

    // MARK: - Helpers

    /// 一次性临时配置文件路径。
    private func makeTemporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-custom-provider-\(UUID().uuidString)")
            .appendingPathExtension("json")
    }

    private func makeConfiguration(
        id: String = "user-custom",
        displayName: String = "团队网关",
        baseURL: String = "https://llm.example.com/v1",
        apiFormat: LLMProviderAPIFormat = .openAI,
        models: [UserDefinedCloudModel] = [UserDefinedCloudModel(id: "team-model")]
    ) -> UserDefinedCloudProviderConfiguration {
        UserDefinedCloudProviderConfiguration(
            id: id,
            displayName: displayName,
            description: "内部 OpenAI 兼容服务",
            baseURL: baseURL,
            apiFormat: apiFormat,
            defaultModel: models.first?.id ?? "",
            models: models,
            websiteURLString: "https://llm.example.com"
        )
    }

    // MARK: - 新增

    @Test("新增供应商后配置落盘并注册到管理器")
    func upsertPersistsAndRegistersProvider() throws {
        let fileURL = makeTemporaryFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let manager = DefaultLLMProviderManagerProviding()
        let store = UserDefinedCloudProviderStore(fileURL: fileURL)
        store.attach(manager: manager, apiService: VendorAPIService())
        let configuration = makeConfiguration()

        try store.upsert(configuration)

        #expect(store.configurations == [configuration])
        #expect(manager.provider(id: configuration.id) is UserDefinedCloudProvider)
        #expect(manager.models(for: configuration.id) == ["team-model"])
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test("同一 ID 再次新增是覆盖而不是追加")
    func upsertReplacesConfigurationWithSameIdentifier() throws {
        let fileURL = makeTemporaryFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let manager = DefaultLLMProviderManagerProviding()
        let store = UserDefinedCloudProviderStore(fileURL: fileURL)
        store.attach(manager: manager, apiService: VendorAPIService())
        let original = makeConfiguration()
        try store.upsert(original)

        let renamed = makeConfiguration(displayName: "改名后的网关")
        try store.upsert(renamed)

        #expect(store.configurations.count == 1)
        #expect(store.configurations.first?.displayName == "改名后的网关")
        #expect(manager.provider(id: original.id)?.providerInfo.displayName == "改名后的网关")
    }

    @Test("配置非法时新增失败且不落盘不注册")
    func upsertRejectsInvalidConfigurationWithoutSideEffects() throws {
        let fileURL = makeTemporaryFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let manager = DefaultLLMProviderManagerProviding()
        let store = UserDefinedCloudProviderStore(fileURL: fileURL)
        store.attach(manager: manager, apiService: VendorAPIService())

        // Base URL 非法
        #expect(throws: UserDefinedCloudProviderError.invalidBaseURL) {
            try store.upsert(makeConfiguration(baseURL: "not-a-url"))
        }
        // 名称为空
        #expect(throws: UserDefinedCloudProviderError.missingDisplayName) {
            try store.upsert(makeConfiguration(displayName: "  "))
        }
        // 模型为空
        #expect(throws: UserDefinedCloudProviderError.missingModel) {
            try store.upsert(makeConfiguration(models: []))
        }

        #expect(store.configurations.isEmpty)
        #expect(manager.allProviders().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test("未装配管理器时新增失败并报持久化错误")
    func upsertFailsWhenManagerNotAttached() {
        let fileURL = makeTemporaryFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let store = UserDefinedCloudProviderStore(fileURL: fileURL)

        #expect(throws: UserDefinedCloudProviderError.persistenceFailed) {
            try store.upsert(makeConfiguration())
        }
        #expect(store.configurations.isEmpty)
    }

    // MARK: - 删除

    @Test("删除供应商会注销运行时实例并更新磁盘配置")
    func removeUnregistersProviderAndDeletesConfiguration() throws {
        let fileURL = makeTemporaryFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let manager = DefaultLLMProviderManagerProviding()
        let store = UserDefinedCloudProviderStore(fileURL: fileURL)
        store.attach(manager: manager, apiService: VendorAPIService())
        let configuration = makeConfiguration()
        try store.upsert(configuration)

        try store.remove(id: configuration.id)

        #expect(store.configurations.isEmpty)
        #expect(manager.provider(id: configuration.id) == nil)
        #expect(UserDefinedCloudProviderStore(fileURL: fileURL).configurations.isEmpty)
    }

    @Test("删除不存在的 ID 是空操作")
    func removeIgnoresUnknownIdentifier() throws {
        let fileURL = makeTemporaryFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let manager = DefaultLLMProviderManagerProviding()
        let store = UserDefinedCloudProviderStore(fileURL: fileURL)
        store.attach(manager: manager, apiService: VendorAPIService())
        try store.upsert(makeConfiguration())

        try store.remove(id: "not-exist")

        #expect(store.configurations.count == 1)
    }

    // MARK: - 恢复与装配

    @Test("重启后从磁盘恢复自定义供应商")
    func restoresConfigurationsFromDisk() throws {
        let fileURL = makeTemporaryFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let manager = DefaultLLMProviderManagerProviding()
        let store = UserDefinedCloudProviderStore(fileURL: fileURL)
        store.attach(manager: manager, apiService: VendorAPIService())
        let configuration = makeConfiguration()
        try store.upsert(configuration)

        let restored = UserDefinedCloudProviderStore(fileURL: fileURL)

        #expect(restored.configurations == [configuration])
    }

    @Test("装配时把磁盘上的供应商注册进管理器")
    func attachRegistersRestoredProviders() throws {
        let fileURL = makeTemporaryFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let firstManager = DefaultLLMProviderManagerProviding()
        let firstStore = UserDefinedCloudProviderStore(fileURL: fileURL)
        firstStore.attach(manager: firstManager, apiService: VendorAPIService())
        let configuration = makeConfiguration()
        try firstStore.upsert(configuration)

        // 模拟重启：新 Store 读同一份磁盘配置，装配到新的管理器
        let secondManager = DefaultLLMProviderManagerProviding()
        let secondStore = UserDefinedCloudProviderStore(fileURL: fileURL)
        secondStore.attach(manager: secondManager, apiService: VendorAPIService())

        #expect(secondManager.provider(id: configuration.id) is UserDefinedCloudProvider)
        #expect(secondManager.models(for: configuration.id) == ["team-model"])
    }

    @Test("磁盘上损坏的配置在加载时被丢弃")
    func dropsInvalidConfigurationsWhenLoading() throws {
        let fileURL = makeTemporaryFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL) }

        // 名称为空 → 校验失败 → 加载时被丢弃；另一条合法配置保留。
        let payload: [[String: Any]] = [
            [
                "id": "user-bad",
                "displayName": "",
                "description": "",
                "baseURL": "https://llm.example.com/v1",
                "apiFormatRawValue": "openAI",
                "defaultModel": "m1",
                "models": [
                    ["id": "m1", "displayName": "m1", "contextWindowSize": NSNull(),
                     "supportsVision": false, "supportsTools": true]
                ],
                "websiteURLString": NSNull()
            ],
            [
                "id": "user-good",
                "displayName": "有效供应商",
                "description": "",
                "baseURL": "https://llm.example.com/v1",
                "apiFormatRawValue": "openAI",
                "defaultModel": "m2",
                "models": [
                    ["id": "m2", "displayName": "m2", "contextWindowSize": NSNull(),
                     "supportsVision": false, "supportsTools": true]
                ],
                "websiteURLString": NSNull()
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        try data.write(to: fileURL, options: .atomic)

        let store = UserDefinedCloudProviderStore(fileURL: fileURL)

        #expect(store.configurations.map(\.id) == ["user-good"])
    }

    @Test("磁盘文件不存在时加载为空配置")
    func loadsEmptyWhenFileMissing() {
        let fileURL = makeTemporaryFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let store = UserDefinedCloudProviderStore(fileURL: fileURL)

        #expect(store.configurations.isEmpty)
    }

    @Test("能识别某个 ID 是否为自定义供应商")
    func reportsCustomProviderMembership() throws {
        let fileURL = makeTemporaryFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let manager = DefaultLLMProviderManagerProviding()
        let store = UserDefinedCloudProviderStore(fileURL: fileURL)
        store.attach(manager: manager, apiService: VendorAPIService())
        let configuration = makeConfiguration()
        try store.upsert(configuration)

        #expect(store.isCustomProvider(id: configuration.id))
        #expect(!store.isCustomProvider(id: "built-in-provider"))
    }

    // MARK: - 供应商适配

    @Test("自定义供应商按所选 API 格式暴露对应配置")
    func userDefinedProviderExposesFormatSpecificConfiguration() {
        let openAIProvider = UserDefinedCloudProvider(
            configuration: makeConfiguration(apiFormat: .openAI)
        )
        #expect(openAIProvider.openAIConfiguration?.baseURL == "https://llm.example.com/v1")
        #expect(openAIProvider.anthropicConfiguration == nil)

        let anthropicProvider = UserDefinedCloudProvider(
            configuration: makeConfiguration(apiFormat: .anthropic)
        )
        #expect(anthropicProvider.anthropicConfiguration?.baseURL == "https://llm.example.com/v1")
        #expect(anthropicProvider.openAIConfiguration == nil)

        let responsesProvider = UserDefinedCloudProvider(
            configuration: makeConfiguration(apiFormat: .responses)
        )
        #expect(responsesProvider.responsesEndpointURL == "https://llm.example.com/v1")
    }

    @Test("自定义供应商在管理器中暴露为云端供应商")
    func userDefinedProviderIsRegisteredAsRemoteProvider() throws {
        let fileURL = makeTemporaryFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let manager = DefaultLLMProviderManagerProviding()
        let store = UserDefinedCloudProviderStore(fileURL: fileURL)
        store.attach(manager: manager, apiService: VendorAPIService())
        let configuration = makeConfiguration()
        try store.upsert(configuration)

        let provider = manager.provider(id: configuration.id)

        #expect(provider?.providerInfo.isLocal == false)
        #expect(provider?.providerInfo.displayName == "团队网关")
        #expect(provider?.providerInfo.apiKeyStorageKey == configuration.apiKeyStorageKey)
    }
}
