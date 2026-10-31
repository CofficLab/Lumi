import Foundation
import KitLLM
import ProviderLLMManager
import Testing
@testable import PluginToolLLMProvider

/// 提案载荷的编解码：工具写、渲染器读，两边必须对得上。
struct ProviderProposalPayloadTests {

    private func makeProposal() -> LLMProviderProposal {
        LLMProviderProposal(
            id: "custom-acme",
            displayName: "Acme Gateway",
            providerDescription: "团队内部网关",
            baseURL: "https://api.acme.example.com/v1",
            apiFormat: .openAI,
            defaultModel: "acme-large",
            models: [
                UserDefinedCloudModel(id: "acme-large", displayName: "Acme Large"),
                UserDefinedCloudModel(id: "acme-small"),
            ],
            websiteURLString: "https://acme.example.com"
        )
    }

    @Test("编码后可以原样解码回来")
    func roundTripsProposal() throws {
        let proposal = makeProposal()
        let encoded = ProviderProposalPayload.encode(proposal)
        #expect(encoded.hasPrefix("```json"))
        #expect(encoded.hasSuffix("```"))

        let decoded = try #require(ProviderProposalPayload.decode(from: encoded))
        #expect(decoded == proposal)
    }

    @Test("正文里出现更早的代码块时只取第一段 JSON")
    func decodesFirstJSONBlock() {
        let proposal = makeProposal()
        let content = """
        ## 提案

        下面是 ```json 的示例：```json
        {"unrelated": true}
        ```

        \(ProviderProposalPayload.encode(proposal))
        """
        let decoded = ProviderProposalPayload.decode(from: content)
        #expect(decoded?.id == "custom-acme")
    }

    @Test("没有 JSON 代码块时返回 nil")
    func returnsNilWithoutPayload() {
        #expect(ProviderProposalPayload.decode(from: "只是普通文本") == nil)
        #expect(ProviderProposalPayload.decode(from: "") == nil)
    }

    @Test("JSON 非法时返回 nil 而不是崩溃")
    func returnsNilForMalformedJSON() {
        #expect(ProviderProposalPayload.decode(from: "```json\n{ 不是 json\n```") == nil)
    }

    @Test("提案可以转换为供应商配置")
    func convertsToConfiguration() {
        let configuration = makeProposal().makeConfiguration()
        #expect(configuration.id == "custom-acme")
        #expect(configuration.displayName == "Acme Gateway")
        #expect(configuration.baseURL == "https://api.acme.example.com/v1")
        #expect(configuration.apiFormat == .openAI)
        #expect(configuration.defaultModel == "acme-large")
        #expect(configuration.models.count == 2)
        #expect(configuration.websiteURLString == "https://acme.example.com")
    }

    @Test("协议原始值非法时退化为 OpenAI 兼容")
    func fallsBackToOpenAIForUnknownFormat() {
        let proposal = LLMProviderProposal(
            id: "custom-x",
            displayName: "X",
            baseURL: "https://x.example.com/v1",
            apiFormat: .openAI,
            defaultModel: "m",
            models: [UserDefinedCloudModel(id: "m")]
        )
        var broken = proposal
        broken.apiFormatRawValue = "not-a-format"
        #expect(broken.apiFormat == .openAI)
    }
}
