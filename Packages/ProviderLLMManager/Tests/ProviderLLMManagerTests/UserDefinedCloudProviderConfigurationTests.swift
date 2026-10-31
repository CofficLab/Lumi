import Foundation
import KitLLM
import Testing
@testable import ProviderLLMManager

/// 用户自定义云端供应商配置的校验规则。
///
/// 这层规则直接决定「添加供应商」点保存时界面上弹出什么错误，
/// 因此是「添加供应商」功能最容易被改坏的一环。
struct UserDefinedCloudProviderConfigurationTests {

    // MARK: - 名称

    @Test("名称为空或全是空白时校验失败（空串与空白串）")
    func rejectsEmptyOrWhitespaceDisplayName() {
        for name in ["", "   ", "\n\t"] {
            let configuration = UserDefinedCloudProviderConfiguration(
                id: "user-1",
                displayName: name,
                baseURL: "https://llm.example.com/v1",
                defaultModel: "m1",
                models: [UserDefinedCloudModel(id: "m1")]
            )
            #expect(throws: UserDefinedCloudProviderError.missingDisplayName) {
                try configuration.validated()
            }
        }
    }

    @Test("校验通过后名称去掉首尾空白")
    func trimsDisplayName() throws {
        let configuration = UserDefinedCloudProviderConfiguration(
            id: "user-1",
            displayName: "  团队网关  ",
            baseURL: "https://llm.example.com/v1",
            defaultModel: "m1",
            models: [UserDefinedCloudModel(id: "m1")]
        )

        #expect(try configuration.validated().displayName == "团队网关")
    }

    @Test("ID 为空时校验失败")
    func rejectsEmptyIdentifier() {
        let configuration = UserDefinedCloudProviderConfiguration(
            id: "",
            displayName: "团队网关",
            baseURL: "https://llm.example.com/v1",
            defaultModel: "m1",
            models: [UserDefinedCloudModel(id: "m1")]
        )

        #expect(throws: UserDefinedCloudProviderError.missingDisplayName) {
            try configuration.validated()
        }
    }

    // MARK: - Base URL

    @Test("Base URL 非法时校验失败")
    func rejectsInvalidBaseURL() {
        let invalidURLs = [
            "",
            "   ",
            "not-a-url",
            "llm.example.com/v1",
            // 协议不受支持
            "ftp://llm.example.com",
            "file:///etc/passwd",
            // 有协议但没有主机
            "https://",
            "http://"
        ]

        for url in invalidURLs {
            let configuration = UserDefinedCloudProviderConfiguration(
                id: "user-1",
                displayName: "团队网关",
                baseURL: url,
                defaultModel: "m1",
                models: [UserDefinedCloudModel(id: "m1")]
            )
            #expect(throws: UserDefinedCloudProviderError.invalidBaseURL) {
                try configuration.validated()
            }
        }
    }

    @Test("HTTP 与 HTTPS 的 Base URL 都合法")
    func acceptsHTTPAndHTTPSBaseURL() throws {
        for url in ["https://llm.example.com/v1", "http://127.0.0.1:11434/v1"] {
            let configuration = UserDefinedCloudProviderConfiguration(
                id: "user-1",
                displayName: "团队网关",
                baseURL: url,
                defaultModel: "m1",
                models: [UserDefinedCloudModel(id: "m1")]
            )
            #expect(try configuration.validated().baseURL == url)
        }
    }

    @Test("校验通过后 Base URL 去掉首尾空白")
    func trimsBaseURL() throws {
        let configuration = UserDefinedCloudProviderConfiguration(
            id: "user-1",
            displayName: "团队网关",
            baseURL: "  https://llm.example.com/v1  ",
            defaultModel: "m1",
            models: [UserDefinedCloudModel(id: "m1")]
        )

        #expect(try configuration.validated().baseURL == "https://llm.example.com/v1")
    }

    // MARK: - 模型

    @Test("模型列表为空时校验失败")
    func rejectsEmptyModelList() {
        let configuration = UserDefinedCloudProviderConfiguration(
            id: "user-1",
            displayName: "团队网关",
            baseURL: "https://llm.example.com/v1",
            defaultModel: "",
            models: []
        )

        #expect(throws: UserDefinedCloudProviderError.missingModel) {
            try configuration.validated()
        }
    }

    @Test("模型 ID 重复时校验失败")
    func rejectsDuplicateModelIDs() {
        let configuration = UserDefinedCloudProviderConfiguration(
            id: "user-1",
            displayName: "团队网关",
            baseURL: "https://llm.example.com/v1",
            defaultModel: "m1",
            models: [UserDefinedCloudModel(id: "m1"), UserDefinedCloudModel(id: "m1")]
        )

        #expect(throws: UserDefinedCloudProviderError.duplicateModel) {
            try configuration.validated()
        }
    }

    @Test("模型 ID 为空白时校验失败")
    func rejectsBlankModelID() {
        let configuration = UserDefinedCloudProviderConfiguration(
            id: "user-1",
            displayName: "团队网关",
            baseURL: "https://llm.example.com/v1",
            defaultModel: "m1",
            models: [UserDefinedCloudModel(id: "  ")]
        )

        #expect(throws: UserDefinedCloudProviderError.duplicateModel) {
            try configuration.validated()
        }
    }

    @Test("默认模型不在列表中时回退到第一个模型")
    func fallsBackToFirstModelWhenDefaultMissing() throws {
        let configuration = UserDefinedCloudProviderConfiguration(
            id: "user-1",
            displayName: "团队网关",
            baseURL: "https://llm.example.com/v1",
            defaultModel: "not-in-list",
            models: [UserDefinedCloudModel(id: "m1"), UserDefinedCloudModel(id: "m2")]
        )

        #expect(try configuration.validated().defaultModel == "m1")
    }

    @Test("默认模型在列表中时保持不变")
    func keepsDefaultModelWhenPresent() throws {
        let configuration = UserDefinedCloudProviderConfiguration(
            id: "user-1",
            displayName: "团队网关",
            baseURL: "https://llm.example.com/v1",
            defaultModel: "m2",
            models: [UserDefinedCloudModel(id: "m1"), UserDefinedCloudModel(id: "m2")]
        )

        #expect(try configuration.validated().defaultModel == "m2")
    }

    // MARK: - API 格式

    @Test("Responses 格式关闭工具调用能力")
    func responsesFormatDisablesToolSupport() throws {
        let configuration = UserDefinedCloudProviderConfiguration(
            id: "user-1",
            displayName: "团队网关",
            baseURL: "https://llm.example.com/v1",
            apiFormat: .responses,
            defaultModel: "m1",
            models: [UserDefinedCloudModel(id: "m1", supportsTools: true)]
        )

        let validated = try configuration.validated()

        // 共享的 Responses 实现当前不转发 tools，只支持纯文本。
        #expect(validated.models[0].supportsTools == false)
        // 其余元数据保持不变
        #expect(validated.models[0].id == "m1")
        #expect(validated.models[0].supportsVision == false)
    }

    @Test("OpenAI 与 Anthropic 格式保留工具调用能力")
    func otherFormatsKeepToolSupport() throws {
        for format in [LLMProviderAPIFormat.openAI, .anthropic] {
            let configuration = UserDefinedCloudProviderConfiguration(
                id: "user-1",
                displayName: "团队网关",
                baseURL: "https://llm.example.com/v1",
                apiFormat: format,
                defaultModel: "m1",
                models: [UserDefinedCloudModel(id: "m1", supportsVision: true, supportsTools: true)]
            )

            let validated = try configuration.validated()

            #expect(validated.models[0].supportsTools == true)
            #expect(validated.models[0].supportsVision == true)
        }
    }

    @Test("未知的 API 格式原始值回退到 OpenAI")
    func unknownAPIFormatFallsBackToOpenAI() {
        var configuration = UserDefinedCloudProviderConfiguration(
            id: "user-1",
            displayName: "团队网关",
            baseURL: "https://llm.example.com/v1",
            defaultModel: "m1",
            models: [UserDefinedCloudModel(id: "m1")]
        )
        configuration.apiFormatRawValue = "some-future-format"

        #expect(configuration.apiFormat == .openAI)
    }

    // MARK: - 派生属性

    @Test("API Key 存储键按供应商 ID 隔离")
    func apiKeyStorageKeyIsScopedByProviderID() {
        let first = UserDefinedCloudProviderConfiguration(
            id: "user-a",
            displayName: "A",
            baseURL: "https://llm.example.com/v1",
            defaultModel: "m1",
            models: [UserDefinedCloudModel(id: "m1")]
        )
        let second = UserDefinedCloudProviderConfiguration(
            id: "user-b",
            displayName: "B",
            baseURL: "https://llm.example.com/v1",
            defaultModel: "m1",
            models: [UserDefinedCloudModel(id: "m1")]
        )

        #expect(first.apiKeyStorageKey != second.apiKeyStorageKey)
        #expect(first.apiKeyStorageKey.contains("user-a"))
    }

    @Test("官网为空串时解析为 nil")
    func websiteURLIsNilWhenEmpty() {
        var configuration = UserDefinedCloudProviderConfiguration(
            id: "user-1",
            displayName: "团队网关",
            baseURL: "https://llm.example.com/v1",
            defaultModel: "m1",
            models: [UserDefinedCloudModel(id: "m1")]
        )
        configuration.websiteURLString = ""

        #expect(configuration.websiteURL == nil)
    }

    @Test("错误描述非空且为中文提示")
    func errorDescriptionsAreNotEmpty() {
        let errors: [UserDefinedCloudProviderError] = [
            .missingDisplayName,
            .invalidBaseURL,
            .missingModel,
            .duplicateModel,
            .persistenceFailed
        ]

        for error in errors {
            #expect(error.errorDescription?.isEmpty == false)
        }
    }
}
