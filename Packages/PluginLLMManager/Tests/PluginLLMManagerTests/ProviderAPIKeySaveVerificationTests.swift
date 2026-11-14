import Foundation
import KitLLM
import ProviderMessage
import Testing

@testable import PluginLLMManager

/// 回归 #1119：对话内 API Key 卡片必须在凭据真正落盘后才显示 Saved。
@MainActor
struct ProviderAPIKeySaveVerificationTests {

    @Test("Keychain 写入失败时不显示 Saved 并保留输入")
    func writeFailureKeepsInputAndReportsError() async {
        let (viewModel, provider) = makeViewModel(
            writeError: VendorAPIKeyStorageError.writeFailed
        )
        viewModel.apiKey = "sk-new"

        viewModel.saveAPIKey()
        await waitForSave(viewModel)

        #expect(!viewModel.didSaveAPIKey)
        #expect(viewModel.saveError == VendorAPIKeyStorageError.writeFailed.localizedDescription)
        #expect(viewModel.apiKey == "sk-new")
        #expect(provider.storedKey.isEmpty)
    }

    @Test("静默写失败不会被当作保存成功")
    func silentWriteLossIsNotReportedAsSaved() async {
        let (viewModel, provider) = makeViewModel(
            storedKey: "sk-old",
            ignoresSuccessfulWrites: true
        )
        viewModel.apiKey = "sk-new"

        viewModel.saveAPIKey()
        await waitForSave(viewModel)

        #expect(provider.storedKey == "sk-old")
        #expect(!viewModel.didSaveAPIKey)
        #expect(viewModel.saveError != nil)
        #expect(viewModel.apiKey == "sk-new")
    }

    @Test("读回值与提交值一致才显示 Saved")
    func readBackMatchConfirmsSave() async {
        let (viewModel, provider) = makeViewModel()
        viewModel.apiKey = "  sk-new  "

        viewModel.saveAPIKey()
        await waitForSave(viewModel)

        #expect(provider.storedKey == "sk-new")
        #expect(viewModel.didSaveAPIKey)
        #expect(viewModel.saveError == nil)
        #expect(viewModel.apiKey == "sk-new")
        #expect(viewModel.keyIsReadable)
    }

    /// 等待异步保存完成。
    ///
    /// - Note: 保存现在走后台线程（Keychain 同步 IPC 不能在主线程做，
    ///   见 issue #1286），因此断言前需要让出一轮主 actor。
    private func waitForSave(_ viewModel: ProviderAPIKeyViewModel) async {
        for _ in 0..<50 {
            if viewModel.didSaveAPIKey || viewModel.saveError != nil { return }
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    // MARK: - Helpers

    private func makeViewModel(
        storedKey: String = "",
        writeError: Error? = nil,
        ignoresSuccessfulWrites: Bool = false
    ) -> (ProviderAPIKeyViewModel, StubAPIKeyProvider) {
        let provider = StubAPIKeyProvider(
            storedKey: storedKey,
            writeError: writeError,
            ignoresSuccessfulWrites: ignoresSuccessfulWrites
        )
        let capability = StubCapability(stubProvider: provider)
        let message = Message(
            conversationID: UUID(),
            role: .error,
            content: "API Key missing",
            isError: true,
            providerID: provider.providerID
        )
        let viewModel = ProviderAPIKeyViewModel(
            capability: capability,
            message: message,
            keyOperations: StubAPIKeyProvider.keyOperations(for: provider)
        )
        return (viewModel, provider)
    }
}

@MainActor
private final class StubCapability: LLMManagerCapability {
    private let stubProvider: StubAPIKeyProvider

    init(stubProvider: StubAPIKeyProvider) {
        self.stubProvider = stubProvider
    }

    var selectedProviderID: String? { stubProvider.providerID }

    func provider(id: String) -> (any SuperLLMProvider)? {
        id == stubProvider.providerID ? stubProvider : nil
    }

    func allProviders() -> [any SuperLLMProvider] {
        [stubProvider]
    }

    func select(providerID: String, model: String?) {}
}

@MainActor
private final class StubAPIKeyProvider: SuperLLMProvider {
    /// 供 ViewModel 注入的 Key 操作。
    ///
    /// - Note: 复用 stub 自身的同步实现，测试因此无需触碰真实 Keychain。
    ///   每个 stub 实例用自己的 storageKey，互不干扰。
    static func keyOperations(for provider: StubAPIKeyProvider) -> ProviderAPIKeyViewModel.KeyOperations {
        ProviderAPIKeyViewModel.KeyOperations(
            read: { _ in
                await MainActor.run { provider.storedKey }
            },
            resolve: { _, displayName in
                let value = await MainActor.run { provider.storedKey }
                guard !value.isEmpty else {
                    throw VendorAPIError.missingAPIKey(displayName)
                }
                return value
            },
            write: { _, apiKey in
                try await MainActor.run {
                    try provider.writeForTest(apiKey)
                }
            }
        )
    }

    let providerInfo: LLMProviderInfo
    private(set) var storedKey: String
    private let writeError: Error?
    private let ignoresSuccessfulWrites: Bool

    init(
        storedKey: String = "",
        writeError: Error? = nil,
        ignoresSuccessfulWrites: Bool = false
    ) {
        self.storedKey = storedKey
        self.writeError = writeError
        self.ignoresSuccessfulWrites = ignoresSuccessfulWrites
        self.providerInfo = LLMProviderInfo(
            id: "stub-api-key-provider",
            displayName: "Stub API Key Provider",
            defaultModel: "stub-model",
            models: [LLMModelInfo(id: "stub-model", contextWindowSize: 8_000)]
        )
    }

    var providerID: String { providerInfo.id }

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        LLMResponse(content: "", model: request.model)
    }

    func getApiKey() -> String {
        storedKey
    }

    func setApiKeyReportingErrors(_ apiKey: String) throws {
        try writeForTest(apiKey)
    }

    /// 写入 Key；供 `keyOperations` 在主 actor 上调用。
    func writeForTest(_ apiKey: String) throws {
        if let writeError {
            throw writeError
        }
        guard !ignoresSuccessfulWrites else { return }
        storedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
