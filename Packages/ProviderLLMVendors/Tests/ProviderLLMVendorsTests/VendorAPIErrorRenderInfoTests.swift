import Foundation
import Testing
@testable import ProviderLLMVendors

@MainActor
struct VendorAPIErrorRenderInfoTests {

    @Test("missingAPIKey 携带缺失渲染类型与原始详情")
    func missingAPIKeyRenderInfo() {
        let error = VendorAPIError.missingAPIKey("DeepSeek")
        #expect(error.renderKind == LLMErrorRenderKind.apiKeyMissing)
        #expect(error.rawErrorDetail == "Missing API key for: DeepSeek")
        #expect(error.localizedDescription.contains("DeepSeek"))
    }

    @Test("apiKeyAccessFailed 携带读取失败渲染类型与详情")
    func apiKeyAccessFailedRenderInfo() {
        let error = VendorAPIError.apiKeyAccessFailed(provider: "DeepSeek", details: "Keychain read error (-25308)")
        #expect(error.renderKind == LLMErrorRenderKind.apiKeyAccessFailed)
        #expect(error.rawErrorDetail == "Keychain read error (-25308)")
        #expect(error.localizedDescription.contains("DeepSeek"))
    }

    @Test("其余错误不携带渲染类型,走默认错误渲染")
    func otherErrorsHaveNoRenderKind() {
        let cases: [VendorAPIError] = [
            .httpStatus(429, "rate limited"),
            .emptyResponse,
            .requestFailed("network down"),
            .decodingFailed("bad json"),
            .invalidBaseURL("https://x"),
        ]
        for error in cases {
            #expect(error.renderKind == nil)
            #expect(error.rawErrorDetail == nil)
        }
    }
}
