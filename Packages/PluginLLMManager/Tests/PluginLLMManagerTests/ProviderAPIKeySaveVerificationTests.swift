import Foundation
import KitLLM
import ProviderMessage
import Testing

@testable import PluginLLMManager

/// 回归 #1119：对话内 API Key 卡片必须在凭据真正落盘后才显示 Saved。
@MainActor
struct ProviderAPIKeySaveVerificationTests {

    @Test("Keychain 写入失败时不显示 Saved 并保留输入")
    func writeFailureKeepsInputAndReportsError() {
        let (viewModel, provider) = makeViewModel(
            writeError: VendorAPIKeyStorageError.writeFailed
        )
        viewModel.apiKey = "sk-new"

        viewModel.saveAPIKey()

        #expect(!viewModel.didSaveAPIKey)
        #expect(viewModel.saveError == VendorAPIKeyStorageError.writeFailed.localizedDescription)
        #expect(viewModel.apiKey == "sk-new")
        #expect(provider.storedKey.isEmpty)
    }

    @Test("静默写失败不会被当作保存成功")
    func silentWriteLossIsNotReportedAsSaved() {
        let (viewModel, provider) = makeViewModel(
            storedKey: "sk-old",
            ignoresSuccessfulWrites: true
        )
        viewModel.apiKey = "sk-new"

        viewModel.saveAPIKey()

        #expect(provider.storedKey == "sk-old")
        #expect(!viewModel.didSaveAPIKey)
        #expect(viewModel.saveError != nil)
        #expect(viewModel.apiKey == "sk-new")
    }

    @Test("读回值与提交值一致才显示 Saved")
    func readBackMatchConfirmsSave() {
        let (viewModel, provider) = makeViewModel()
        viewModel.apiKey = "  sk-new  "

        viewModel.saveAPIKey()

        #expect(provider.storedKey == "sk-new")
        #expect(viewModel.didSaveAPIKey)
        #expect(viewModel.saveError == nil)
        #expect(viewModel.apiKey == "sk-new")
        #expect(viewModel.keyIsReadable)
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
        let viewModel = ProviderAPIKeyViewModel(capability: capability, message: message)
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
        if let writeError {
            throw writeError
        }
        guard !ignoresSuccessfulWrites else { return }
        storedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
