import Foundation
import KitLLM
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderSettings

/// 供应商详情页 API Key 保存 / 删除的失败反馈（#563）。
///
/// 底层写入接口不抛错（静默失败），ViewModel 若无条件更新成功态，
/// 用户看到的是「已保存」绿标，重启后 Key 却不存在（删除失败则旧 Key
/// 复活）。这里锁定保存 / 删除后的回读校验：失败必须写入
/// `apiKeySaveError`，成功态与输入框保持原样。
@MainActor
struct ProviderDetailAPIKeyErrorTests {

    /// 静默失败桩：写入与删除均为空操作，回读永远返回旧值。
    private final class FailingKeyProvider: ManagedLLMProvider {
        let providerInfo: LLMProviderInfo
        private let storedKey: String

        init(id: String, storedKey: String = "") {
            self.storedKey = storedKey
            providerInfo = LLMProviderInfo(
                id: id,
                displayName: "失败供应商",
                description: "",
                defaultModel: "model-a",
                models: [LLMModelInfo(id: "model-a")],
                apiKeyStorageKey: "test.\(id)"
            )
        }

        var providerID: String { providerInfo.id }

        func getApiKey() -> String { storedKey }

        func complete(_ request: LLMRequest) async throws -> LLMResponse {
            LLMResponse(content: "mock", model: request.model)
        }

        func setApiKey(_ apiKey: String) {}

        func removeApiKey() {}
    }

    /// 记录式桩供应商：写入 / 删除都成功，用于锁定正常路径不受影响。
    private final class RecordingKeyProvider: ManagedLLMProvider {
        let providerInfo: LLMProviderInfo
        private(set) var savedKey: String?

        init(id: String) {
            providerInfo = LLMProviderInfo(
                id: id,
                displayName: "记录供应商",
                description: "",
                defaultModel: "model-a",
                models: [LLMModelInfo(id: "model-a")],
                apiKeyStorageKey: "test.\(id)"
            )
        }

        var providerID: String { providerInfo.id }

        func getApiKey() -> String { savedKey ?? "" }

        func complete(_ request: LLMRequest) async throws -> LLMResponse {
            LLMResponse(content: "mock", model: request.model)
        }

        func setApiKey(_ apiKey: String) { savedKey = apiKey }

        func removeApiKey() { savedKey = nil }
    }

    private func makeViewModel(
        provider: any ManagedLLMProvider,
        manager: DefaultLLMProviderManagerProviding
    ) throws -> ProviderDetailViewModel {
        try manager.register(provider)
        let capability = ProviderSettingsCapabilityAdapter(manager: manager, customProviderStore: nil)
        return ProviderDetailViewModel(
            capability: capability,
            providerID: provider.providerID,
            downloadViewModel: nil
        )
    }

    @Test("保存失败必须展示错误并保持旧成功态（#563）")
    func saveFailureSurfacesErrorAndKeepsState() throws {
        let manager = DefaultLLMProviderManagerProviding()
        let viewModel = try makeViewModel(
            provider: FailingKeyProvider(id: "failing-save"),
            manager: manager
        )

        viewModel.apiKey = "new-secret"
        viewModel.saveAPIKey()

        #expect(viewModel.apiKeySaveError != nil)
        #expect(viewModel.savedAPIKey.isEmpty)
        #expect(viewModel.apiKey == "new-secret")
    }

    @Test("删除失败必须展示错误且不得清空已保存 Key（#563）")
    func removeFailureSurfacesErrorAndKeepsKey() throws {
        let manager = DefaultLLMProviderManagerProviding()
        let viewModel = try makeViewModel(
            provider: FailingKeyProvider(id: "failing-remove", storedKey: "stored-secret"),
            manager: manager
        )

        #expect(viewModel.savedAPIKey == "stored-secret")
        viewModel.removeAPIKey()

        #expect(viewModel.apiKeySaveError != nil)
        #expect(viewModel.savedAPIKey == "stored-secret")
        #expect(viewModel.apiKey == "stored-secret")
    }

    @Test("保存与删除成功时清空错误并更新成功态（#563 护栏）")
    func successPathsStillWork() throws {
        let manager = DefaultLLMProviderManagerProviding()
        let provider = RecordingKeyProvider(id: "recording-key")
        let viewModel = try makeViewModel(provider: provider, manager: manager)

        viewModel.apiKey = "fresh-secret"
        viewModel.saveAPIKey()

        #expect(viewModel.apiKeySaveError == nil)
        #expect(viewModel.savedAPIKey == "fresh-secret")
        #expect(provider.savedKey == "fresh-secret")

        viewModel.removeAPIKey()

        #expect(viewModel.apiKeySaveError == nil)
        #expect(viewModel.savedAPIKey.isEmpty)
        #expect(provider.savedKey == nil)
    }
}
