import Foundation
import KitLLM
import Testing
@testable import ProviderLLMManager

/// 回归 #334：自定义供应商把 API 根地址原样当作请求端点。
///
/// `add_llm_provider` 约定 baseURL 填 API 根（如 https://api.example.com/v1），
/// 而 KitLLM 的适配器按「baseURL 即完整端点」原样 POST。三个协议都必须把各自的
/// 操作路径追加到根地址之后，流式与非流式共用同一配置，否则请求落到 /v1 而 404/405。
@MainActor
@Suite("自定义供应商端点路径")
struct UserDefinedCloudProviderEndpointTests {

    private func makeProvider(
        baseURL: String,
        apiFormat: LLMProviderAPIFormat
    ) -> UserDefinedCloudProvider {
        UserDefinedCloudProvider(
            configuration: UserDefinedCloudProviderConfiguration(
                id: "user-custom",
                displayName: "团队网关",
                baseURL: baseURL,
                apiFormat: apiFormat,
                defaultModel: "m1",
                models: [UserDefinedCloudModel(id: "m1")]
            )
        )
    }

    @Test("OpenAI 格式在 API 根后追加 /chat/completions")
    func openAIAppendsChatCompletionsPath() {
        let provider = makeProvider(baseURL: "https://api.example.com/v1", apiFormat: .openAI)
        #expect(provider.openAIConfiguration?.baseURL == "https://api.example.com/v1/chat/completions")
    }

    @Test("Anthropic 格式在 API 根后追加 /messages")
    func anthropicAppendsMessagesPath() {
        let provider = makeProvider(baseURL: "https://api.example.com/v1", apiFormat: .anthropic)
        #expect(provider.anthropicConfiguration?.baseURL == "https://api.example.com/v1/messages")
    }

    @Test("Responses 格式在 API 根后追加 /responses")
    func responsesAppendsResponsesPath() {
        let provider = makeProvider(baseURL: "https://api.example.com/v1", apiFormat: .responses)
        #expect(provider.responsesEndpointURL == "https://api.example.com/v1/responses")
    }

    @Test("根地址带尾斜杠时不产生双斜杠")
    func trailingSlashDoesNotDoubleSlash() {
        let openAI = makeProvider(baseURL: "https://api.example.com/v1/", apiFormat: .openAI)
        #expect(openAI.openAIConfiguration?.baseURL == "https://api.example.com/v1/chat/completions")

        let anthropic = makeProvider(baseURL: "https://api.example.com/v1/", apiFormat: .anthropic)
        #expect(anthropic.anthropicConfiguration?.baseURL == "https://api.example.com/v1/messages")

        let responses = makeProvider(baseURL: "https://api.example.com/v1/", apiFormat: .responses)
        #expect(responses.responsesEndpointURL == "https://api.example.com/v1/responses")
    }

    @Test("根地址不含版本前缀时同样追加操作路径")
    func rootWithoutVersionPrefixStillAppendsPath() {
        let provider = makeProvider(baseURL: "https://api.example.com", apiFormat: .openAI)
        #expect(provider.openAIConfiguration?.baseURL == "https://api.example.com/chat/completions")
    }

    @Test("非 OpenAI 格式不暴露 OpenAI 配置")
    func openAIConfigurationNilForOtherFormats() {
        for format in [LLMProviderAPIFormat.anthropic, .responses] {
            let provider = makeProvider(baseURL: "https://api.example.com/v1", apiFormat: format)
            #expect(provider.openAIConfiguration == nil)
        }
    }

    @Test("非 Anthropic 格式不暴露 Anthropic 配置")
    func anthropicConfigurationNilForOtherFormats() {
        for format in [LLMProviderAPIFormat.openAI, .responses] {
            let provider = makeProvider(baseURL: "https://api.example.com/v1", apiFormat: format)
            #expect(provider.anthropicConfiguration == nil)
        }
    }
}