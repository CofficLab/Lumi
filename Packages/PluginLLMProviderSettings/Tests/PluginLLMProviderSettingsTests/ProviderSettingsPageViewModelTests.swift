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

    /// 计数标签跟随界面语言变化，断言时按当前语言现算，避免写死中文。
    private func providerCountLabel(_ count: Int, isLocal: Bool) -> String {
        let key = isLocal ? "%lld 个本地供应商" : "%lld 个云端供应商"
        return String(format: pluginLocalization.string(key), Int64(count))
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
        #expect(viewModel.providerCountLabel == providerCountLabel(0, isLocal: false))

        try store.upsert(makeConfiguration())

        #expect(viewModel.providerCountLabel == providerCountLabel(1, isLocal: false))
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
        #expect(viewModel.providerCountLabel == providerCountLabel(0, isLocal: false))
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
        #expect(cloudViewModel.providerCountLabel == providerCountLabel(1, isLocal: false))
        #expect(localViewModel.providerCountLabel == providerCountLabel(1, isLocal: true))
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

    /// 回归 #941：搜索只过滤左侧列表，右侧详情仍展示选中的供应商。
    /// 头部模型数量曾从过滤后的列表里查找选中项，搜索把它排除后数量
    /// 变成 `0 个模型`，与右侧详情矛盾。
    @Test("搜索排除当前供应商时头部模型数量保持不变")
    func searchDoesNotZeroSelectedProviderModelCount() throws {
        let (manager, _, capability) = makeFixture()
        try manager.register(
            MockRemoteProvider(
                id: "provider-p",
                displayName: "供应商 P",
                models: [LLMModelInfo(id: "m1"), LLMModelInfo(id: "m2")]
            )
        )
        try manager.register(MockRemoteProvider(id: "provider-q", displayName: "供应商 Q"))

        let viewModel = makeViewModel(capability: capability)
        viewModel.selectProvider(id: "provider-p")
        viewModel.searchText = "Q"

        #expect(viewModel.filteredProviders.map(\.providerInfo.id) == ["provider-q"])
        #expect(viewModel.selectedProvider?.providerInfo.id == "provider-p")
        #expect(viewModel.selectedModelCount == 2, "详情仍展示 P，头部就必须显示 P 的模型数")

        // 列表刷新也不能因为搜索词把选中项改成过滤后的第一项。
        viewModel.synchronizeSelection()
        #expect(viewModel.selectedProviderID == "provider-p")
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

    // MARK: - 详情 · 全局选中

    /// 回归 #940：详情只在初始化时读取一次全局选中模型，别处（模型选择器、
    /// 会话联动、其他供应商）切换后仍把旧模型标成「当前」。全局选中变化
    /// 时必须刷新详情快照。
    @Test("全局选中变化后详情刷新「当前」模型")
    func detailRefreshesSelectedModelAfterExternalSelection() throws {
        let (manager, _, capability) = makeFixture()
        try manager.register(
            MockRemoteProvider(
                id: "provider-p",
                displayName: "供应商 P",
                models: [LLMModelInfo(id: "m1"), LLMModelInfo(id: "m2")]
            )
        )
        try manager.register(
            MockRemoteProvider(
                id: "provider-q",
                displayName: "供应商 Q",
                models: [LLMModelInfo(id: "m3")]
            )
        )

        let page = makeViewModel(capability: capability)
        let detail = page.detailViewModel(for: "provider-p")
        detail.select(modelID: "m1")
        #expect(detail.isModelSelected("m1"))

        capability.select(providerID: "provider-q", model: "m3")
        #expect(detail.isModelSelected("m1") == false, "P 的模型已不是全局选中")
        #expect(detail.selectedModelID == capability.selectedModelID)
    }

    // MARK: - API Key 明文状态

    /// 回归 #942：明文展示状态曾保存在详情视图的本地 `@State` 里。切换
    /// 供应商时 SwiftUI 复用同一视图身份，把旧供应商的「已展开」状态传给
    /// 新供应商，新凭据未经点击就以明文出现。状态现在归属按供应商缓存的
    /// ViewModel，切换后必须重新隐藏。
    @Test("切换供应商后不得继承上一个供应商的 API Key 明文状态")
    func apiKeyRevealStateIsScopedToProvider() throws {
        let (manager, _, capability) = makeFixture()
        try manager.register(MockRemoteProvider(id: "provider-p", displayName: "供应商 P"))
        try manager.register(MockRemoteProvider(id: "provider-q", displayName: "供应商 Q"))

        let page = makeViewModel(capability: capability)
        let first = page.detailViewModel(for: "provider-p")
        #expect(first.isAPIKeyRevealed == false)

        first.isAPIKeyRevealed = true
        let second = page.detailViewModel(for: "provider-q")
        #expect(second.isAPIKeyRevealed == false, "新供应商必须默认隐藏 API Key")

        let firstAgain = page.detailViewModel(for: "provider-p")
        #expect(firstAgain === first, "同一供应商复用缓存的 ViewModel")
        #expect(firstAgain.isAPIKeyRevealed == true, "明文状态属于原供应商")
    }
}
