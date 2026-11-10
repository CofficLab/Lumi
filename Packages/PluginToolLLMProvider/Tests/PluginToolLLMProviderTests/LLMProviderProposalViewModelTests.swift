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

    /// 回归 #542：凭据没写进 Keychain 时不能报告 Added，也不能清空输入。
    @Test("API Key 写入失败时保留输入并报错")
    func saveSurfacesAPIKeyWriteFailure() throws {
        let manager = FailingKeyLLMManager(providerID: "custom-acme")
        let (store, fileURL) = makeStore(manager: manager)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let viewModel = LLMProviderProposalViewModel(
            proposal: makeProposal(),
            store: store,
            manager: manager
        )
        viewModel.apiKey = "sk-test-secret"
        viewModel.save()

        guard case .failed = viewModel.phase else {
            Issue.record("凭据写入失败时不应显示 Added")
            return
        }
        #expect(viewModel.apiKey == "sk-test-secret", "失败后必须保留用户输入")
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

    /// 回归 #948：保存会 trim 默认模型，选择时若用未 trim 的草稿就会退回首模型。
    @Test("默认模型带首尾空白时按 trim 后的结果选中")
    func selectAsCurrentUsesTrimmedDefaultModel() throws {
        let manager = DefaultLLMProviderManagerProviding()
        let (store, fileURL) = makeStore(manager: manager)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        var proposal = makeProposal()
        proposal.models = [
            UserDefinedCloudModel(id: "acme-large"),
            UserDefinedCloudModel(id: "acme-small"),
        ]
        let viewModel = LLMProviderProposalViewModel(
            proposal: proposal,
            store: store,
            manager: manager
        )
        viewModel.defaultModel = " acme-small "
        viewModel.save()

        #expect(viewModel.defaultModel == "acme-small")
        #expect(store.configurations.first?.defaultModel == "acme-small")

        viewModel.selectAsCurrent()

        #expect(manager.selectedProviderID == "custom-acme")
        #expect(manager.selectedModel == "acme-small")
    }

    /// 回归 #946：会话绑定过模型后 AgentLoop 优先用会话模型，只写全局选择无效。
    @Test("Use This Provider 同时把模型写回卡片所属会话")
    func selectingWritesModelToCardConversation() throws {
        let manager = DefaultLLMProviderManagerProviding()
        let (store, fileURL) = makeStore(manager: manager)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let conversationID = UUID()
        let selection = SpyConversationModelSelection()
        let viewModel = LLMProviderProposalViewModel(
            proposal: makeProposal(),
            store: store,
            manager: manager,
            conversationID: conversationID,
            conversationSelection: selection
        )
        viewModel.save()
        viewModel.selectAsCurrent()

        #expect(manager.selectedProviderID == "custom-acme")
        #expect(selection.calls.count == 1)
        #expect(selection.calls.first?.providerID == "custom-acme")
        #expect(selection.calls.first?.model == "acme-large")
        #expect(selection.calls.first?.conversationID == conversationID)
    }
}

/// 记录按会话写入的模型选择。
@MainActor
private final class SpyConversationModelSelection: ConversationModelSelecting {
    private(set) var calls: [(providerID: String, model: String?, conversationID: UUID)] = []

    func selectProvider(id: String, model: String?, for conversationID: UUID) {
        calls.append((id, model, conversationID))
    }
}

/// 写入 API Key 必然失败的供应商，用于验证卡片把凭据失败暴露出来。
@MainActor
private final class FailingAPIKeyProvider: ManagedLLMProvider {
    let providerInfo: LLMProviderInfo

    init(id: String) {
        providerInfo = LLMProviderInfo(
            id: id,
            displayName: "Failing",
            defaultModel: "model-a",
            models: [LLMModelInfo(id: "model-a")],
            apiKeyStorageKey: "test.\(id)"
        )
    }

    var providerID: String { providerInfo.id }
    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        LLMResponse(content: "", model: request.model)
    }
    func setApiKey(_ apiKey: String) {}
    func setApiKeyReportingErrors(_ apiKey: String) throws {
        throw VendorAPIKeyStorageError.writeFailed
    }
    func removeApiKey() {}
}

/// 最小可用的 manager：注册照常成功，但取到的供应商写入凭据必然失败。
@MainActor
private final class FailingKeyLLMManager: LLMManaging {
    let providerInfo = LLMProviderInfo(
        id: "failing-manager",
        displayName: "Failing Manager",
        defaultModel: "model-a",
        models: [LLMModelInfo(id: "model-a")]
    )
    var providerID: String { providerInfo.id }
    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        LLMResponse(content: "", model: request.model)
    }

    private var registered: [any SuperLLMProvider] = []
    private let failingProvider: FailingAPIKeyProvider

    init(providerID: String) {
        failingProvider = FailingAPIKeyProvider(id: providerID)
    }

    func allProviders() -> [any SuperLLMProvider] { registered }
    func provider(id: String) -> (any SuperLLMProvider)? {
        if id == failingProvider.providerID { return failingProvider }
        return registered.first { $0.providerID == id }
    }
    var providerCount: Int { registered.count }
    func register(_ provider: any SuperLLMProvider) throws { registered.append(provider) }
    func unregister(id: String) { registered.removeAll { $0.providerID == id } }

    var selectedProviderID: String?
    var selectedModel: String?
    func models(for providerID: String) -> [String] { [] }
    func select(providerID: String, model: String?, reason: ModelSelectionReason) {
        selectedProviderID = providerID
        selectedModel = model
    }
}
