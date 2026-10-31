import Foundation
import KitLLM
import ProviderLLMManager
import Testing
@testable import PluginToolLLMProvider

/// 提案卡片的视图模型：保存、冲突与草稿编辑。
@MainActor
struct LLMProviderProposalViewModelTests {

    /// 测试用内置供应商（模拟「id 已被内置实现占用」的场景）。
    private final class MockBuiltinProvider: ManagedLLMProvider {
        let providerInfo: LLMProviderInfo
        private var storedKey: String = ""

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
        func hasApiKey() -> Bool { !storedKey.isEmpty }
        func getApiKey() -> String { storedKey }
        func setApiKey(_ apiKey: String) { storedKey = apiKey }
        func removeApiKey() { storedKey = "" }
    }

    // MARK: - Helpers

    private func makeTemporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-provider-proposal-\(UUID().uuidString)")
            .appendingPathExtension("json")
    }

    private func makeProposal(
        id: String = "custom-acme",
        baseURL: String = "https://api.acme.example.com/v1"
    ) -> LLMProviderProposal {
        LLMProviderProposal(
            id: id,
            displayName: "Acme Gateway",
            providerDescription: "团队网关",
            baseURL: baseURL,
            apiFormat: .openAI,
            defaultModel: "acme-large",
            models: [UserDefinedCloudModel(id: "acme-large")]
        )
    }

    private func makeStore(
        manager: (any LLMManaging)
    ) -> (UserDefinedCloudProviderStore, URL) {
        let fileURL = makeTemporaryFileURL()
        let store = UserDefinedCloudProviderStore(fileURL: fileURL)
        store.attach(manager: manager, apiService: VendorAPIService())
        return (store, fileURL)
    }

    // MARK: - 保存

    @Test("保存后配置落盘并注册到管理器")
    func savePersistsAndRegistersProvider() throws {
        let manager = DefaultLLMProviderManagerProviding()
        let (store, fileURL) = makeStore(manager: manager)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let viewModel = LLMProviderProposalViewModel(
            proposal: makeProposal(),
            store: store,
            manager: manager
        )
        viewModel.save()

        #expect(viewModel.phase == .saved)
        #expect(store.configurations.count == 1)
        #expect(store.configurations.first?.id == "custom-acme")
        #expect(manager.provider(id: "custom-acme") is UserDefinedCloudProvider)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test("保存后 API Key 写入供应商并从界面状态里清空")
    func saveWritesAPIKeyAndClearsIt() throws {
        let manager = DefaultLLMProviderManagerProviding()
        let (store, fileURL) = makeStore(manager: manager)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let viewModel = LLMProviderProposalViewModel(
            proposal: makeProposal(),
            store: store,
            manager: manager
        )
        viewModel.apiKey = "sk-test-secret"
        viewModel.save()

        #expect(viewModel.phase == .saved)
        #expect(viewModel.apiKey.isEmpty)
        #expect(manager.provider(id: "custom-acme")?.getApiKey() == "sk-test-secret")
    }

    @Test("端点不合规时保存失败且不落盘")
    func saveRejectsInsecureEndpoint() throws {
        let manager = DefaultLLMProviderManagerProviding()
        let (store, fileURL) = makeStore(manager: manager)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let viewModel = LLMProviderProposalViewModel(
            proposal: makeProposal(baseURL: "http://api.acme.example.com/v1"),
            store: store,
            manager: manager
        )
        viewModel.save()

        guard case .failed = viewModel.phase else {
            Issue.record("保存应当失败")
            return
        }
        #expect(store.configurations.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test("标识与内置供应商冲突时拒绝写入")
    func saveRefusesToOverwriteBuiltinProvider() throws {
        let manager = DefaultLLMProviderManagerProviding()
        try manager.register(MockBuiltinProvider(id: "custom-acme", displayName: "Builtin"))
        let (store, fileURL) = makeStore(manager: manager)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let viewModel = LLMProviderProposalViewModel(
            proposal: makeProposal(),
            store: store,
            manager: manager
        )
        viewModel.save()

        guard case .failed = viewModel.phase else {
            Issue.record("保存应当失败")
            return
        }
        #expect(store.configurations.isEmpty)
        #expect(manager.provider(id: "custom-acme") is MockBuiltinProvider)
    }

    @Test("模型为空时保存失败（模型必须由用户补齐）")
    func saveRejectsEmptyModelList() throws {
        let manager = DefaultLLMProviderManagerProviding()
        let (store, fileURL) = makeStore(manager: manager)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        var proposal = makeProposal()
        proposal.models = []
        proposal.defaultModel = ""

        let viewModel = LLMProviderProposalViewModel(
            proposal: proposal,
            store: store,
            manager: manager
        )
        viewModel.save()

        guard case .failed = viewModel.phase else {
            Issue.record("保存应当失败")
            return
        }
        #expect(store.configurations.isEmpty)
    }

    @Test("没有 Store 时保存失败而不是静默成功")
    func saveFailsWithoutStore() {
        let viewModel = LLMProviderProposalViewModel(
            proposal: makeProposal(),
            store: nil,
            manager: nil
        )
        viewModel.save()

        guard case .failed = viewModel.phase else {
            Issue.record("保存应当失败")
            return
        }
    }

    // MARK: - 草稿编辑

    @Test("追加模型时去重并同步默认模型")
    func addPendingModelDeduplicates() {
        let viewModel = LLMProviderProposalViewModel(
            proposal: makeProposal(),
            store: nil,
            manager: nil
        )
        viewModel.pendingModelID = "acme-large"
        viewModel.addPendingModel()
        #expect(viewModel.models.count == 1)

        viewModel.pendingModelID = "acme-small"
        viewModel.addPendingModel()
        #expect(viewModel.models.count == 2)
        #expect(viewModel.models.map(\.id) == ["acme-large", "acme-small"])
    }

    @Test("移除模型时若移除的是默认模型则回落到第一个")
    func removeModelUpdatesDefault() {
        let viewModel = LLMProviderProposalViewModel(
            proposal: makeProposal(),
            store: nil,
            manager: nil
        )
        viewModel.pendingModelID = "acme-small"
        viewModel.addPendingModel()
        #expect(viewModel.defaultModel == "acme-large")

        viewModel.removeModel(id: "acme-large")
        #expect(viewModel.defaultModel == "acme-small")
    }

    // MARK: - 选中

    @Test("保存成功后可以设为当前供应商")
    func selectAsCurrentAfterSave() throws {
        let manager = DefaultLLMProviderManagerProviding()
        let (store, fileURL) = makeStore(manager: manager)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let viewModel = LLMProviderProposalViewModel(
            proposal: makeProposal(),
            store: store,
            manager: manager
        )
        viewModel.save()
        viewModel.selectAsCurrent()

        #expect(manager.selectedProviderID == "custom-acme")
        #expect(manager.selectedModel == "acme-large")
    }
}
