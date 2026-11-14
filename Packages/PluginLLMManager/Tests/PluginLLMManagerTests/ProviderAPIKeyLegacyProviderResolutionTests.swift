import Foundation
import KitLLM
import ProviderMessage
import Testing

@testable import PluginLLMManager

/// 回归 #1120：没有 `providerID` 的旧 API Key 错误消息必须绑定它自己记录的
/// 供应商，不能借用当前全局选中的供应商——否则保存会写错 Keychain 条目。
@MainActor
struct ProviderAPIKeyLegacyProviderResolutionTests {

    @Test("旧消息按 rawErrorDetail 中的供应商名绑定")
    func legacyRawErrorDetailBindsOwningProvider() async {
        let (viewModel, providerA, providerB) = makeViewModel(
            message: legacyMessage(rawErrorDetail: "Missing API key for: Provider A")
        )

        #expect(viewModel.providerAvailable)
        #expect(!viewModel.requiresManualProviderSelection)
        #expect(viewModel.providerName == "Provider A")

        viewModel.apiKey = "sk-a"
        viewModel.saveAPIKey()
        await waitForSave(viewModel)

        #expect(providerA.storedKey == "sk-a")
        #expect(providerB.storedKey == "sk-b")
        #expect(viewModel.didSaveAPIKey)
    }

    @Test("旧版 missingAPIKey 文本同样按供应商名绑定")
    func legacyContentBindsOwningProvider() async {
        let (viewModel, providerA, providerB) = makeViewModel(
            message: legacyMessage(content: "missingAPIKey(\"Provider A\")")
        )

        #expect(viewModel.providerAvailable)
        #expect(viewModel.providerName == "Provider A")

        viewModel.apiKey = "sk-a"
        viewModel.saveAPIKey()
        await waitForSave(viewModel)

        #expect(providerA.storedKey == "sk-a")
        #expect(providerB.storedKey == "sk-b")
    }

    @Test("旧消息记录的供应商未注册时禁用内联写入")
    func unknownLegacyProviderDisablesInlineSave() async {
        let (viewModel, providerA, providerB) = makeViewModel(
            message: legacyMessage(rawErrorDetail: "Missing API key for: Provider C")
        )

        #expect(!viewModel.providerAvailable)
        #expect(viewModel.requiresManualProviderSelection)
        #expect(viewModel.providerName == "Provider C")

        viewModel.apiKey = "sk-c"
        viewModel.saveAPIKey()
        await waitForSave(viewModel)

        #expect(providerA.storedKey == "sk-a")
        #expect(providerB.storedKey == "sk-b")
        #expect(!viewModel.didSaveAPIKey)
    }

    @Test("旧消息无法解析供应商身份时不回退到当前选中项")
    func identitylessLegacyMessageDisablesInlineSave() async {
        let (viewModel, providerA, providerB) = makeViewModel(
            message: legacyMessage(content: "API Key missing")
        )

        #expect(!viewModel.providerAvailable)
        #expect(viewModel.requiresManualProviderSelection)
        #expect(viewModel.apiKey.isEmpty)

        viewModel.apiKey = "sk-should-not-save"
        viewModel.saveAPIKey()
        await waitForSave(viewModel)

        #expect(providerA.storedKey == "sk-a")
        #expect(providerB.storedKey == "sk-b")
        #expect(!viewModel.didSaveAPIKey)
    }

    @Test("展示名重复时无法唯一归属，禁用内联写入")
    func ambiguousDisplayNameDisablesInlineSave() async {
        let (viewModel, providerA, providerB) = makeViewModel(
            message: legacyMessage(rawErrorDetail: "Missing API key for: Provider A"),
            duplicateDisplayName: true
        )

        #expect(!viewModel.providerAvailable)
        #expect(viewModel.requiresManualProviderSelection)

        viewModel.apiKey = "sk-ambiguous"
        viewModel.saveAPIKey()
        await waitForSave(viewModel)

        #expect(providerA.storedKey == "sk-a")
        #expect(providerB.storedKey == "sk-b")
        #expect(!viewModel.didSaveAPIKey)
    }

    // MARK: - Helpers

    /// 等待异步保存完成。
    ///
    /// - Note: 保存走后台线程（Keychain 同步 IPC 不能在主线程做，
    ///   见 issue #1286），断言前需要让出一轮主 actor。
    private func waitForSave(_ viewModel: ProviderAPIKeyViewModel) async {
        for _ in 0..<50 {
            if viewModel.didSaveAPIKey || viewModel.saveError != nil { return }
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    private func legacyMessage(
        content: String = "API Key missing",
        rawErrorDetail: String? = nil
    ) -> Message {
        Message(
            conversationID: UUID(),
            role: .error,
            content: content,
            isError: true,
            rawErrorDetail: rawErrorDetail
        )
    }

    private func makeViewModel(
        message: Message,
        duplicateDisplayName: Bool = false
    ) -> (ProviderAPIKeyViewModel, LegacyStubProvider, LegacyStubProvider) {
        let providerA = LegacyStubProvider(
            id: "provider-a",
            displayName: "Provider A",
            storedKey: "sk-a"
        )
        let providerB = LegacyStubProvider(
            id: "provider-b",
            displayName: duplicateDisplayName ? "Provider A" : "Provider B",
            storedKey: "sk-b"
        )
        let capability = LegacyStubCapability(
            providers: [providerA, providerB],
            selectedProviderID: providerB.providerID
        )
        // 注入 stub 的 Key 操作：保存是异步的（Keychain 同步 IPC 不能在
        // 主线程做，见 issue #1286），测试必须走与生产一致的路径。
        let viewModel = ProviderAPIKeyViewModel(
            capability: capability,
            message: message,
            keyOperations: ProviderAPIKeyViewModel.KeyOperations(
                read: { storageKey in
                    await MainActor.run {
                        storageKey == providerA.providerInfo.apiKeyStorageKey
                            ? providerA.storedKey
                            : providerB.storedKey
                    }
                },
                resolve: { storageKey, displayName in
                    let value = await MainActor.run {
                        storageKey == providerA.providerInfo.apiKeyStorageKey
                            ? providerA.storedKey
                            : providerB.storedKey
                    }
                    guard !value.isEmpty else {
                        throw VendorAPIError.missingAPIKey(displayName)
                    }
                    return value
                },
                write: { storageKey, apiKey in
                    await MainActor.run {
                        if storageKey == providerA.providerInfo.apiKeyStorageKey {
                            providerA.setStoredKeyForTest(apiKey)
                        } else {
                            providerB.setStoredKeyForTest(apiKey)
                        }
                    }
                }
            )
        )
        return (viewModel, providerA, providerB)
    }
}

@MainActor
private final class LegacyStubCapability: LLMManagerCapability {
    private let providers: [LegacyStubProvider]
    let selectedProviderID: String?

    init(providers: [LegacyStubProvider], selectedProviderID: String?) {
        self.providers = providers
        self.selectedProviderID = selectedProviderID
    }

    func provider(id: String) -> (any SuperLLMProvider)? {
        providers.first { $0.providerID == id }
    }

    func allProviders() -> [any SuperLLMProvider] {
        providers
    }

    func select(providerID: String, model: String?) {}
}

@MainActor
private final class LegacyStubProvider: SuperLLMProvider {
    let providerInfo: LLMProviderInfo
    private(set) var storedKey: String

    init(id: String, displayName: String, storedKey: String) {
        self.providerInfo = LLMProviderInfo(
            id: id,
            displayName: displayName,
            defaultModel: "\(id)-model",
            models: [LLMModelInfo(id: "\(id)-model", contextWindowSize: 8_000)]
        )
        self.storedKey = storedKey
    }

    var providerID: String { providerInfo.id }

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        LLMResponse(content: "", model: request.model)
    }

    func getApiKey() -> String {
        storedKey
    }

    func setApiKeyReportingErrors(_ apiKey: String) throws {
        setStoredKeyForTest(apiKey)
    }

    /// 写入 Key；供 `keyOperations` 在主 actor 上调用。
    func setStoredKeyForTest(_ apiKey: String) {
        storedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
