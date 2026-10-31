import Foundation
import KitAgentTool
import KitLLM
import ProviderLLMManager
import Testing
@testable import PluginToolLLMProvider

/// `add_llm_provider` 工具的行为约定。
///
/// 重点不在「能不能跑通」，而在**它不许做什么**：不落盘、不注册、不经手密钥。
struct AddLLMProviderToolTests {

    private func makeTool() -> AddLLMProviderTool {
        AddLLMProviderTool()
    }

    private func arguments(
        displayName: String? = "Acme Gateway",
        baseURL: String? = "https://api.acme.example.com/v1",
        apiFormat: String? = nil,
        defaultModel: String? = nil,
        models: [Any]? = nil,
        websiteURL: String? = nil,
        description: String? = nil
    ) -> [String: ToolArgument] {
        var result: [String: ToolArgument] = [:]
        if let displayName { result["displayName"] = ToolArgument(displayName) }
        if let baseURL { result["baseURL"] = ToolArgument(baseURL) }
        if let apiFormat { result["apiFormat"] = ToolArgument(apiFormat) }
        if let defaultModel { result["defaultModel"] = ToolArgument(defaultModel) }
        if let models { result["models"] = ToolArgument(models) }
        if let websiteURL { result["websiteURL"] = ToolArgument(websiteURL) }
        if let description { result["description"] = ToolArgument(description) }
        return result
    }

    // MARK: - 正常路径

    @Test("合法参数产出可解码的提案载荷")
    func producesDecodableProposal() async throws {
        let tool = makeTool()
        let text = try await tool.execute(arguments: arguments(
            defaultModel: "acme-large",
            models: [
                ["id": "acme-large", "displayName": "Acme Large", "contextWindowSize": 128000],
                ["id": "acme-small", "supportsVision": true],
            ],
            websiteURL: "https://acme.example.com",
            description: "团队网关"
        ))

        let proposal = try #require(ProviderProposalPayload.decode(from: text))
        #expect(proposal.displayName == "Acme Gateway")
        #expect(proposal.baseURL == "https://api.acme.example.com/v1")
        #expect(proposal.apiFormat == .openAI)
        #expect(proposal.defaultModel == "acme-large")
        #expect(proposal.models.count == 2)
        #expect(proposal.models.first?.displayName == "Acme Large")
        #expect(proposal.models.first?.contextWindowSize == 128000)
        #expect(proposal.models.last?.supportsVision == true)
        #expect(proposal.models.last?.supportsTools == true)
        #expect(proposal.websiteURLString == "https://acme.example.com")
        #expect(proposal.providerDescription == "团队网关")
    }

    @Test("未指定协议时默认为 OpenAI 兼容")
    func defaultsToOpenAIFormat() async throws {
        let text = try await makeTool().execute(arguments: arguments())
        let proposal = try #require(ProviderProposalPayload.decode(from: text))
        #expect(proposal.apiFormat == .openAI)
    }

    @Test("显式指定 anthropic 协议被保留")
    func keepsExplicitFormat() async throws {
        let text = try await makeTool().execute(
            arguments: arguments(apiFormat: "anthropic", defaultModel: "claude")
        )
        let proposal = try #require(ProviderProposalPayload.decode(from: text))
        #expect(proposal.apiFormat == .anthropic)
    }

    @Test("未指定默认模型时回落到第一个模型")
    func fallsBackToFirstModel() async throws {
        let text = try await makeTool().execute(arguments: arguments(
            models: [["id": "m1"], ["id": "m2"]]
        ))
        let proposal = try #require(ProviderProposalPayload.decode(from: text))
        #expect(proposal.defaultModel == "m1")
    }

    // MARK: - 拒绝路径

    @Test("缺少展示名时报错")
    func rejectsMissingDisplayName() async {
        await #expect(throws: ToolExecutionError.self) {
            try await makeTool().execute(arguments: arguments(displayName: nil))
        }
    }

    @Test("缺少地址时报错")
    func rejectsMissingBaseURL() async {
        await #expect(throws: ToolExecutionError.self) {
            try await makeTool().execute(arguments: arguments(baseURL: nil))
        }
    }

    @Test("私网地址被拒绝")
    func rejectsPrivateNetworkEndpoint() async {
        await #expect(throws: ToolExecutionError.self) {
            try await makeTool().execute(arguments: arguments(baseURL: "https://192.168.1.10/v1"))
        }
    }

    @Test("远端明文 http 被拒绝")
    func rejectsPlaintextRemoteEndpoint() async {
        await #expect(throws: ToolExecutionError.self) {
            try await makeTool().execute(arguments: arguments(baseURL: "http://api.example.com/v1"))
        }
    }

    @Test("模型为空时仍然产出提案（模型由用户在卡片里补齐）")
    func allowsEmptyModelList() async throws {
        let text = try await makeTool().execute(arguments: arguments(models: []))
        let proposal = try #require(ProviderProposalPayload.decode(from: text))
        #expect(proposal.models.isEmpty)
        #expect(proposal.defaultModel.isEmpty)
    }

    @Test("畸形模型条目被跳过而不是让整份提案失败")
    func skipsMalformedModelEntries() async throws {
        let mixedModels: [Any] = [["id": "good"], ["no-id": true], "not-a-dictionary"]
        let text = try await makeTool().execute(arguments: arguments(models: mixedModels))
        let proposal = try #require(ProviderProposalPayload.decode(from: text))
        #expect(proposal.models.count == 1)
        #expect(proposal.models.first?.id == "good")
    }

    // MARK: - 安全约定

    @Test("入参里不存在 API Key 字段")
    func schemaHasNoAPIKeyField() {
        let properties = makeTool().inputSchema(for: .english)["properties"] as? [String: Any]
        let keys = properties?.keys.map { $0.lowercased() } ?? []
        #expect(!keys.contains { $0.contains("apikey") || $0.contains("api_key") || $0.contains("key") })
    }

    @Test("提案载荷里不含 API Key")
    func proposalCarriesNoSecret() async throws {
        let text = try await makeTool().execute(arguments: arguments())
        #expect(!text.lowercased().contains("apikey"))
    }

    @Test("风险等级为中档：不需要审批，但也不是安全操作")
    func usesMediumRiskLevel() {
        #expect(makeTool().permissionRiskLevel(arguments: arguments()) == .medium)
    }

    @Test("展示描述带上供应商名")
    func displayDescriptionIncludesName() {
        let description = makeTool().displayDescription(for: arguments())
        #expect(description.contains("Acme Gateway"))
    }

    // MARK: - 标识

    @Test("供应商标识带 custom- 前缀，避免与内置供应商撞车")
    func prefixesIdentifier() {
        #expect(AddLLMProviderTool.proposedIdentifier(displayName: "DeepSeek") == "custom-deepseek")
        #expect(AddLLMProviderTool.proposedIdentifier(displayName: "Acme Gateway") == "custom-acme-gateway")
        #expect(AddLLMProviderTool.proposedIdentifier(displayName: "  ") == "custom-provider")
        #expect(AddLLMProviderTool.proposedIdentifier(displayName: "OpenAI") == "custom-openai")
    }
}
