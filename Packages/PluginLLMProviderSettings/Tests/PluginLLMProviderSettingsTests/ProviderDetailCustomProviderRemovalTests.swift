import Foundation
import KitLLM
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderSettings

/// 供应商详情页「删除自定义供应商」的失败反馈。
///
/// Store 落盘失败时会保留原配置；如果设置插件把错误吞掉，
/// 用户看到的就是「点了删除、供应商还在、也没有任何提示」。
/// 这里锁定错误必须传到 ViewModel，并由详情页展示。
@MainActor
struct ProviderDetailCustomProviderRemovalTests {

    // MARK: - Helpers

    private func makeConfiguration(
        id: String = "user-removal",
        displayName: String = "团队网关"
    ) -> UserDefinedCloudProviderConfiguration {
        UserDefinedCloudProviderConfiguration(
            id: id,
            displayName: displayName,
            description: "内部 OpenAI 兼容服务",
            baseURL: "https://llm.example.com/v1",
            defaultModel: "team-model",
            models: [UserDefinedCloudModel(id: "team-model")]
        )
    }

    /// 一次性临时目录。
    private func makeTemporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-custom-provider-removal-\(UUID().uuidString)")
    }

    /// 把配置写入磁盘并让 Store 加载，同时返回配置文件所在目录，
    /// 便于测试把它替换成普通文件来阻断后续落盘。
    private func makeLoadedStore(
        configuration: UserDefinedCloudProviderConfiguration
    ) throws -> (store: UserDefinedCloudProviderStore, configurationDirectory: URL) {
        let directory = makeTemporaryDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("providers.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode([configuration]).write(to: fileURL)

        let store = UserDefinedCloudProviderStore(fileURL: fileURL)
        return (store, directory)
    }

    /// 用普通文件占据目录路径，使 `persist` 里的 `createDirectory` 必然失败。
    private func blockPersistence(at directory: URL) throws {
        try FileManager.default.removeItem(at: directory)
        try Data("blocked".utf8).write(to: directory)
    }

    private func makeViewModel(
        store: UserDefinedCloudProviderStore,
        providerID: String,
        manager: DefaultLLMProviderManagerProviding = DefaultLLMProviderManagerProviding()
    ) -> ProviderDetailViewModel {
        let capability = ProviderSettingsCapabilityAdapter(
            manager: manager,
            customProviderStore: store
        )
        return ProviderDetailViewModel(
            capability: capability,
            providerID: providerID,
            downloadViewModel: nil
        )
    }

    // MARK: - 删除失败

    @Test("删除时落盘失败会展示错误并保留供应商")
    func removalFailureSurfacesErrorAndKeepsProvider() throws {
        let configuration = makeConfiguration()
        let (store, directory) = try makeLoadedStore(configuration: configuration)
        defer { try? FileManager.default.removeItem(at: directory) }
        try blockPersistence(at: directory)

        let viewModel = makeViewModel(store: store, providerID: configuration.id)
        viewModel.removeCustomProvider()

        #expect(viewModel.customProviderRemoveError == "供应商配置保存失败。")
        #expect(store.isCustomProvider(id: configuration.id))
        #expect(store.configurations.map(\.id) == [configuration.id])
    }

    @Test("删除成功后不残留上一次的错误")
    func removalSuccessClearsPreviousError() throws {
        let configuration = makeConfiguration()
        let (store, directory) = try makeLoadedStore(configuration: configuration)
        defer { try? FileManager.default.removeItem(at: directory) }

        let viewModel = makeViewModel(store: store, providerID: configuration.id)

        try blockPersistence(at: directory)
        viewModel.removeCustomProvider()
        #expect(viewModel.customProviderRemoveError != nil)

        // 恢复目录后再次删除：错误清空，配置真正移除。
        try FileManager.default.removeItem(at: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        viewModel.removeCustomProvider()

        #expect(viewModel.customProviderRemoveError == nil)
        #expect(store.configurations.isEmpty)
    }
}
