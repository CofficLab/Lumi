import Foundation
import KitLLM
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderSettings

/// 云端 / 本地供应商设置页 ViewModel 的行为。
///
/// 「添加供应商」的用户可感知结果，最终都落在这层：
/// 新增后列表要出现新供应商、计数要变、搜索要能搜到、
/// 选中态要在供应商被删掉后自愈。
@MainActor
struct ProviderSettingsPageViewModelTests {

    // MARK: - Test doubles

    /// 测试用云端供应商。
    private final class MockRemoteProvider: ManagedLLMProvider {
        let providerInfo: LLMProviderInfo

        init(
            id: String,
            displayName: String,
            description: String = "",
            models: [LLMModelInfo] = [LLMModelInfo(id: "model-a")]
        ) {
            providerInfo = LLMProviderInfo(
                id: id,
                displayName: displayName,
                description: description,
                defaultModel: models.first?.id ?? "",
                models: models,
                apiKeyStorageKey: "test.\(id)"
            )
        }

        var providerID: String { providerInfo.id }
        func complete(_ request: LLMRequest) async throws -> LLMResponse {
            LLMResponse(content: "mock", model: request.model)
        }
    }

    /// 测试用本地供应商。
    private final class MockLocalProvider: ManagedLLMProvider {
        let providerInfo: LLMProviderInfo

        init(id: String, displayName: String) {
            providerInfo = LLMProviderInfo(
                id: id,
                displayName: displayName,
                defaultModel: "local-a",
                models: [LLMModelInfo(id: "local-a")],
                isLocal: true
            )
        }

        var providerID: String { providerInfo.id }
        func complete(_ request: LLMRequest) async throws -> LLMResponse {
            LLMResponse(content: "mock", model: request.model)
        }
    }

    // MARK: - Helpers

    private func makeTemporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-page-vm-\(UUID().uuidString)")
            .appendingPathExtension("json")
    }

    private func makeConfiguration(
        id: String = "user-custom",
        displayName: String = "团队网关",
        description: String = "内部服务"
    ) -> UserDefinedCloudProviderConfiguration {
        UserDefinedCloudProviderConfiguration(
            id: id,
            displayName: displayName,
            description: description,
            baseURL: "https://llm.example.com/v1",
            defaultModel: "team-model",
            models: [UserDefinedCloudModel(id: "team-model")]
        )
    }

    /// 装配一个「管理器 + Store + 能力适配器」的三件套。
    private func makeFixture() -> (
        manager: DefaultLLMProviderManagerProviding,
        store: UserDefinedCloudProviderStore,
        capability: ProviderSettingsCapabilityAdapter
    ) {
        let manager = DefaultLLMProviderManagerProviding()
        let store = UserDefinedCloudProviderStore(fileURL: makeTemporaryFileURL())
        store.attach(manager: manager, apiService: VendorAPIService())
        let capability = ProviderSettingsCapabilityAdapter(
            manager: manager,
            customProviderStore: store
        )
        return (manager, store, capability)
    }

    private func makeViewModel(
        capability: ProviderSettingsCapabilityAdapter,
        isLocal: Bool = false
    ) -> ProviderSettingsPageViewModel {
        ProviderSettingsPageViewModel(
            capability: capability,
            isLocal: isLocal,
            downloadViewModel: { _ in nil }
        )
    }

    // MARK: - 添加供应商的主链路

    @Test("新增自定义供应商后立即出现在云端供应商列表")
    func listsNewlyAddedCloudProvider() throws {
        let (manager, store, capability) = makeFixture()
        defer { try? FileManager.default.removeItem(at: store.fileURL!) }
        try manager.register(MockRemoteProvider(id: "built-in", displayName: "内置供应商"))

        let viewModel = makeViewModel(capability: capability)
        viewModel.synchronizeSelection()
        #expect(viewModel.filteredProviders.count == 1)

        let configuration = makeConfiguration()
        try store.upsert(configuration)

        #expect(viewModel.filteredProviders.count == 2)
        #expect(viewModel.filteredProviders.contains { $0.providerInfo.id == configuration.id })
        #expect(viewModel.filteredProviders.contains { $0.providerInfo.displayName == "团队网关" })
    }

    @Test("新增自定义供应商会刷新自定义供应商修订号")
    func customProviderRevisionIncrementsOnStoreChange() throws {
        let (_, store, capability) = makeFixture()
        defer { try? FileManager.default.removeItem(at: store.fileURL!) }

        let viewModel = makeViewModel(capability: capability)
        let before = viewModel.customProviderRevision

        try store.upsert(makeConfiguration())

        #expect(viewModel.customProviderRevision == before + 1)
    }

    @Test("新增后可以按名称搜索到该供应商")
    func newlyAddedProviderIsSearchable() throws {
        let (_, store, capability) = makeFixture()
        defer { try? FileManager.default.removeItem(at: store.fileURL!) }

        let viewModel = makeViewModel(capability: capability)
        try store.upsert(makeConfiguration(id: "user-searchable", displayName: "内部网关"))

        viewModel.searchText = "内部"
        #expect(viewModel.filteredProviders.count == 1)
        #expect(viewModel.filteredProviders.first?.providerInfo.displayName == "内部网关")

        viewModel.searchText = "网关"
        #expect(viewModel.filteredProviders.count == 1)

        viewModel.searchText = "不存在的供应商"
        #expect(viewModel.filteredProviders.isEmpty)
    }

    @Test("新增后供应商计数标签同步更新")
    func providerCountLabelReflectsAddedProvider() throws {
        let (_, store, capability) = makeFixture()
        defer { try? FileManager.default.removeItem(at: store.fileURL!) }

        let viewModel = makeViewModel(capability: capability)
        #expect(viewModel.providerCountLabel == "0 个云端供应商")

        try store.upsert(makeConfiguration())

        #expect(viewModel.providerCountLabel == "1 个云端供应商")
    }

    @Test("新增后选中态自动落到新供应商并显示其模型数")
    func selectsNewlyAddedProviderAndReportsModelCount() throws {
        let (manager, store, capability) = makeFixture()
        defer { try? FileManager.default.removeItem(at: store.fileURL!) }
        try manager.register(MockRemoteProvider(id: "built-in", displayName: "内置供应商"))

        let viewModel = makeViewModel(capability: capability)
        viewModel.synchronizeSelection()
        #expect(viewModel.selectedProviderID == "built-in")
        #expect(viewModel.selectedModelCount == 1)

        let configuration = makeConfiguration()
        try store.upsert(configuration)
        viewModel.synchronizeSelection()

        // 新供应商排在末尾，原选中项仍有效，因此选中态保持不变。
        #expect(viewModel.selectedProviderID == "built-in")

        // 显式切到新供应商后，模型数取自它的模型列表。
        viewModel.selectProvider(id: configuration.id)
        #expect(viewModel.selectedModelCount == 1)
        #expect(viewModel.selectedProvider?.providerInfo.id == configuration.id)
    }

    @Test("删除自定义供应商后列表同步移除")
    func removesProviderFromListAfterDeletion() throws {
        let (_, store, capability) = makeFixture()
        defer { try? FileManager.default.removeItem(at: store.fileURL!) }

        let viewModel = makeViewModel(capability: capability)
        let configuration = makeConfiguration()
        try store.upsert(configuration)
        #expect(viewModel.filteredProviders.count == 1)

        try store.remove(id: configuration.id)

        #expect(viewModel.filteredProviders.isEmpty)
        #expect(viewModel.providerCountLabel == "0 个云端供应商")
    }

    @Test("新增供应商可生成空白编辑器")
    func makesNewCustomProviderEditor() {
        let (_, _, capability) = makeFixture()

        let viewModel = makeViewModel(capability: capability)

        #expect(viewModel.makeNewCustomProviderEditor() != nil)
    }

    @Test("没有自定义供应商 Store 时不生成编辑器")
    func makesNoEditorWithoutStore() {
        let manager = DefaultLLMProviderManagerProviding()
        let capability = ProviderSettingsCapabilityAdapter(manager: manager, customProviderStore: nil)

        let viewModel = makeViewModel(capability: capability)

        #expect(viewModel.makeNewCustomProviderEditor() == nil)
    }

    // MARK: - 作用域与搜索

    @Test("云端页与本地页各自只显示对应作用域的供应商")
    func scopesProvidersByLocalFlag() throws {
        let (manager, store, capability) = makeFixture()
        defer { try? FileManager.default.removeItem(at: store.fileURL!) }
        try manager.register(MockRemoteProvider(id: "remote-1", displayName: "云端供应商"))
        try manager.register(MockLocalProvider(id: "local-1", displayName: "本地供应商"))

        let cloudViewModel = makeViewModel(capability: capability, isLocal: false)
        let localViewModel = makeViewModel(capability: capability, isLocal: true)

        #expect(cloudViewModel.filteredProviders.map(\.providerInfo.id) == ["remote-1"])
        #expect(localViewModel.filteredProviders.map(\.providerInfo.id) == ["local-1"])
        #expect(cloudViewModel.providerCountLabel == "1 个云端供应商")
        #expect(localViewModel.providerCountLabel == "1 个本地供应商")
    }

    @Test("搜索匹配名称、描述与 ID")
    func filtersProvidersBySearchText() throws {
        let (manager, _, capability) = makeFixture()
        try manager.register(
            MockRemoteProvider(id: "alpha", displayName: "阿尔法", description: "第一个供应商")
        )
        try manager.register(
            MockRemoteProvider(id: "beta", displayName: "贝塔", description: "第二个供应商")
        )

        let viewModel = makeViewModel(capability: capability)

        viewModel.searchText = "阿尔法"
        #expect(viewModel.filteredProviders.map(\.providerInfo.id) == ["alpha"])

        viewModel.searchText = "第二个"
        #expect(viewModel.filteredProviders.map(\.providerInfo.id) == ["beta"])

        viewModel.searchText = "beta"
        #expect(viewModel.filteredProviders.map(\.providerInfo.id) == ["beta"])

        // 大小写不敏感
        viewModel.searchText = "BETA"
        #expect(viewModel.filteredProviders.map(\.providerInfo.id) == ["beta"])

        // 空白关键字视为无筛选
        viewModel.searchText = "   "
        #expect(viewModel.filteredProviders.count == 2)
    }

    // MARK: - 选中态

    @Test("没有选中项时自动选中第一个供应商")
    func synchronizeSelectionSelectsFirstProvider() throws {
        let (manager, _, capability) = makeFixture()
        try manager.register(MockRemoteProvider(id: "first", displayName: "第一"))
        try manager.register(MockRemoteProvider(id: "second", displayName: "第二"))

        let viewModel = makeViewModel(capability: capability)
        viewModel.synchronizeSelection()

        #expect(viewModel.selectedProviderID == "first")
    }

    @Test("选中项仍然有效时保持不变")
    func synchronizeSelectionKeepsValidSelection() throws {
        let (manager, _, capability) = makeFixture()
        try manager.register(MockRemoteProvider(id: "first", displayName: "第一"))
        try manager.register(MockRemoteProvider(id: "second", displayName: "第二"))

        let viewModel = makeViewModel(capability: capability)
        viewModel.selectProvider(id: "second")
        viewModel.synchronizeSelection()

        #expect(viewModel.selectedProviderID == "second")
    }

    @Test("选中项被删除后回退到仍然存在的供应商")
    func synchronizeSelectionFallsBackWhenSelectedProviderDisappears() throws {
        let (manager, _, capability) = makeFixture()
        try manager.register(MockRemoteProvider(id: "first", displayName: "第一"))
        try manager.register(MockRemoteProvider(id: "second", displayName: "第二"))

        let viewModel = makeViewModel(capability: capability)
        viewModel.selectProvider(id: "second")

        manager.unregister(id: "second")
        viewModel.synchronizeSelection()

        #expect(viewModel.selectedProviderID == "first")
    }

    @Test("列表为空时没有选中项")
    func synchronizeSelectionClearsWhenListEmpty() {
        let (_, _, capability) = makeFixture()

        let viewModel = makeViewModel(capability: capability)
        viewModel.synchronizeSelection()

        #expect(viewModel.selectedProviderID == nil)
        #expect(viewModel.selectedProvider == nil)
        #expect(viewModel.selectedModelCount == 0)
    }
}
