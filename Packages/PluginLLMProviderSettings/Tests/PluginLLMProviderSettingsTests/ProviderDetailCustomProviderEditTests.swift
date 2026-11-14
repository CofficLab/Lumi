import Foundation
import KitLLM
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderSettings

/// 自定义供应商编辑保存后，详情页必须立即反映新落盘并注册的名称/描述/站点/模型。
///
/// 详情 ViewModel 按供应商 ID 永久缓存；`Store.upsert` 会替换同 ID 的 Provider 并
/// 广播配置变化。若订阅只刷新 `isCustomProvider`，右侧详情会永久停在初始化快照，
/// 切换供应商再回来也无法恢复（#335）。
@MainActor
struct ProviderDetailCustomProviderEditTests {

    private func makeTemporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-custom-provider-edit-\(UUID().uuidString)")
    }

    private func makeAttachedStore(
        manager: DefaultLLMProviderManagerProviding
    ) throws -> (store: UserDefinedCloudProviderStore, directory: URL) {
        let directory = makeTemporaryDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("providers.json")
        let store = UserDefinedCloudProviderStore(fileURL: fileURL)
        store.attach(manager: manager, apiService: VendorAPIService())
        return (store, directory)
    }

    private func makeConfiguration(
        displayName: String,
        description: String,
        websiteURLString: String?,
        modelID: String
    ) -> UserDefinedCloudProviderConfiguration {
        UserDefinedCloudProviderConfiguration(
            id: "user-edit",
            displayName: displayName,
            description: description,
            baseURL: "https://llm.example.com/v1",
            defaultModel: modelID,
            models: [UserDefinedCloudModel(id: modelID)],
            websiteURLString: websiteURLString
        )
    }

    private func makeViewModel(
        store: UserDefinedCloudProviderStore,
        manager: DefaultLLMProviderManagerProviding
    ) -> ProviderDetailViewModel {
        let capability = ProviderSettingsCapabilityAdapter(
            manager: manager,
            customProviderStore: store
        )
        return ProviderDetailViewModel(
            capability: capability,
            providerID: "user-edit",
            downloadViewModel: nil
        )
    }

    @Test("编辑保存后详情页同步新的名称/描述/站点/模型")
    func editRefreshesDisplayedProviderInfo() throws {
        let manager = DefaultLLMProviderManagerProviding()
        let (store, directory) = try makeAttachedStore(manager: manager)
        defer { try? FileManager.default.removeItem(at: directory) }

        try store.upsert(makeConfiguration(
            displayName: "Old Name",
            description: "old description",
            websiteURLString: "https://old.example.com",
            modelID: "m1"
        ))

        let viewModel = makeViewModel(store: store, manager: manager)
        #expect(viewModel.displayName == "Old Name")
        #expect(viewModel.providerDescription == "old description")
        #expect(viewModel.websiteURL == URL(string: "https://old.example.com"))
        #expect(viewModel.models.map(\.id) == ["m1"])

        // 编辑保存：Store 替换同 ID 的 Provider 并广播配置变化。
        try store.upsert(makeConfiguration(
            displayName: "New Name",
            description: "new description",
            websiteURLString: "https://new.example.com",
            modelID: "m2"
        ))

        #expect(viewModel.displayName == "New Name")
        #expect(viewModel.providerDescription == "new description")
        #expect(viewModel.websiteURL == URL(string: "https://new.example.com"))
        #expect(viewModel.models.map(\.id) == ["m2"])
        #expect(viewModel.isCustomProvider)
    }

    @Test("删除自定义供应商后详情页清空名称与模型快照")
    func removalClearsDisplayedProviderInfo() throws {
        let manager = DefaultLLMProviderManagerProviding()
        let (store, directory) = try makeAttachedStore(manager: manager)
        defer { try? FileManager.default.removeItem(at: directory) }

        try store.upsert(makeConfiguration(
            displayName: "Old Name",
            description: "old description",
            websiteURLString: "https://old.example.com",
            modelID: "m1"
        ))

        let viewModel = makeViewModel(store: store, manager: manager)
        #expect(viewModel.displayName == "Old Name")
        #expect(viewModel.models.map(\.id) == ["m1"])

        try store.remove(id: "user-edit")

        // Provider 已注销：详情回退到 providerID 占位，模型池清空，不再标记为自定义。
        #expect(viewModel.displayName == "user-edit")
        #expect(viewModel.models.isEmpty)
        #expect(!viewModel.isCustomProvider)
    }
}