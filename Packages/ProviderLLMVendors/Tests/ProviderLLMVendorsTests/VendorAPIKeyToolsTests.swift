import Foundation
import ProviderLLMManager
import ProviderLLM
import Testing
@testable import ProviderLLMVendors

@MainActor
struct VendorAPIKeyToolsTests {

    private let testKey = "ProviderLLMVendorsTests.test-key"

    /// 本地测试用最小供应商（OpenAI 协议，无真实端点配置），仅用于
    /// 验证未配置 API Key 时的错误路径。
    @MainActor
    private final class TestOpenAIVendor: VendorLLMProvider {
        init() {
            super.init(
                info: LLMProviderInfo(
                    id: "test-vendor",
                    displayName: "Test Vendor",
                    defaultModel: "test-model",
                    models: [LLMModelInfo(id: "test-model")],
                    apiFormat: .openAI,
                    apiKeyStorageKey: "ProviderLLMVendorsTests.test-key"
                )
            )
        }
    }

    @Test("set/get/remove 往返一致")
    func setGetRemoveRoundtrip() {
        VendorAPIKeyTools.set("sk-test-123", storageKey: testKey)
        #expect(VendorAPIKeyTools.get(storageKey: testKey) == "sk-test-123")
        #expect(VendorAPIKeyTools.has(storageKey: testKey))
        #expect((try? VendorAPIKeyTools.resolve(storageKey: testKey, displayName: "Test")) == "sk-test-123")

        VendorAPIKeyTools.remove(storageKey: testKey)
        #expect(!VendorAPIKeyTools.has(storageKey: testKey))
        #expect(VendorAPIKeyTools.get(storageKey: testKey).isEmpty)
        #expect(throws: VendorAPIError.self) {
            _ = try VendorAPIKeyTools.resolve(storageKey: testKey, displayName: "Test")
        }
    }

    @Test("未配置 key 的供应商 complete 抛 missingAPIKey")
    func completeWithoutKeyThrows() async {
        // 用独立测试 key，避免污染真实供应商配置。
        let provider = TestOpenAIVendor()
        await #expect(throws: VendorAPIError.self) {
            _ = try await provider.complete(
                LLMRequest(conversationID: UUID(), messages: [])
            )
        }
    }
}
