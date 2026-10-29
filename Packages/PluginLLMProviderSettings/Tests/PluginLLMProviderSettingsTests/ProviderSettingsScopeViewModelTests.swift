import Foundation
import KitLLM
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderSettings

/// 合并后的供应商页（云端 / 本地共用一个界面）的范围切换行为。
///
/// 「云端供应商」与「本地供应商」原本是两个独立设置入口，现在合并成一个页面，
/// 头部行右上角用分段控件切换范围。切换后必须满足三件事：
///
/// 1. 左侧列表换成对应范围的供应商（不能混着显示）；
/// 2. 右侧详情跟着换（选中项落在新范围的供应商上）；
/// 3. 两个范围各自记住自己的选中项（来回切不互相污染）。
@MainActor
struct ProviderSettingsScopeViewModelTests {

    // MARK: - Test doubles

    /// 测试用云端供应商。
    private final class MockRemoteProvider: ManagedLLMProvider {
        let providerInfo: LLMProviderInfo

        init(id: String, displayName: String) {
            providerInfo = LLMProviderInfo(
                id: id,
                displayName: displayName,
                defaultModel: "model-a",
                models: [LLMModelInfo(id: "model-a")],
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

    private func makeFixture() -> (
        manager: DefaultLLMProviderManagerProviding,
        store: UserDefinedCloudProviderStore,
        capability: ProviderSettingsCapabilityAdapter
    ) {
        let manager = DefaultLLMProviderManagerProviding()
        let store = UserDefinedCloudProviderStore(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("lumi-scope-vm-\(UUID().uuidString)")
                .appendingPathExtension("json")
        )
        store.attach(manager: manager, apiService: VendorAPIService())
        let capability = ProviderSettingsCapabilityAdapter(
            manager: manager,
            customProviderStore: store
        )
        return (manager, store, capability)
    }

    private func makeScopeViewModel(
        capability: ProviderSettingsCapabilityAdapter
    ) -> ProviderSettingsScopeViewModel {
        ProviderSettingsScopeViewModel(
            cloudViewModel: ProviderSettingsPageViewModel(
                capability: capability,
                isLocal: false,
                downloadViewModel: { _ in nil }
            ),
            localViewModel: ProviderSettingsPageViewModel(
                capability: capability,
                isLocal: true,
                downloadViewModel: { _ in nil }
            )
        )
    }

    // MARK: - 用例

    @Test("合并页默认停在云端，列表里只有云端供应商")
    func defaultsToCloudScope() throws {
        let (manager, store, capability) = makeFixture()
        defer { try? FileManager.default.removeItem(at: store.fileURL!) }
        try manager.register(MockRemoteProvider(id: "cloud-1", displayName: "云端一号"))
        try manager.register(MockLocalProvider(id: "local-1", displayName: "本地一号"))

        let scopeViewModel = makeScopeViewModel(capability: capability)

        #expect(scopeViewModel.scope == .cloud)
        #expect(scopeViewModel.activeViewModel.isLocal == false)
        #expect(scopeViewModel.activeViewModel.filteredProviders.map(\.providerInfo.id) == ["cloud-1"])
    }

    @Test("切到本地后列表与详情换成本地供应商，并自动选中第一项")
    func switchingScopeSwapsListAndSelection() throws {
        let (manager, store, capability) = makeFixture()
        defer { try? FileManager.default.removeItem(at: store.fileURL!) }
        try manager.register(MockRemoteProvider(id: "cloud-1", displayName: "云端一号"))
        try manager.register(MockLocalProvider(id: "local-1", displayName: "本地一号"))

        let scopeViewModel = makeScopeViewModel(capability: capability)
        scopeViewModel.selectScope(.local)

        #expect(scopeViewModel.scope == .local)
        #expect(scopeViewModel.activeViewModel.isLocal == true)
        #expect(scopeViewModel.activeViewModel.filteredProviders.map(\.providerInfo.id) == ["local-1"])
        // 详情不能空着：切过去就该落在新范围的第一项上。
        #expect(scopeViewModel.activeViewModel.selectedProviderID == "local-1")
    }

    @Test("两个范围各自记住自己的选中项，来回切不互相污染")
    func scopesKeepIndependentSelection() throws {
        let (manager, store, capability) = makeFixture()
        defer { try? FileManager.default.removeItem(at: store.fileURL!) }
        try manager.register(MockRemoteProvider(id: "cloud-1", displayName: "云端一号"))
        try manager.register(MockRemoteProvider(id: "cloud-2", displayName: "云端二号"))
        try manager.register(MockLocalProvider(id: "local-1", displayName: "本地一号"))

        let scopeViewModel = makeScopeViewModel(capability: capability)
        scopeViewModel.cloudViewModel.selectProvider(id: "cloud-2")

        scopeViewModel.selectScope(.local)
        #expect(scopeViewModel.localViewModel.selectedProviderID == "local-1")

        scopeViewModel.selectScope(.cloud)
        #expect(scopeViewModel.cloudViewModel.selectedProviderID == "cloud-2")
    }

    @Test("范围枚举提供云端 / 本地两个页签标题与图标")
    func scopeExposesTitlesAndIcons() {
        #expect(ProviderSettingsScope.allCases == [.cloud, .local])
        #expect(ProviderSettingsScope.cloud.title == pluginLocalization.string("Cloud"))
        #expect(ProviderSettingsScope.local.title == pluginLocalization.string("Local"))
        #expect(ProviderSettingsScope.cloud.systemImage == "cloud")
        #expect(ProviderSettingsScope.local.systemImage == "cpu")
    }
}
