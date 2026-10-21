import Foundation
import Testing
@testable import KitLLM

// MARK: - 测试替身

/// 工具 schema 替身（`LLMToolSchemaProviding` 需要 `Sendable`）。
private struct FakeToolSchema: LLMToolSchemaProviding, @unchecked Sendable {
    let name: String
    let toolDescription: String
    let inputSchema: [String: Any]

    init(name: String, toolDescription: String = "", inputSchema: [String: Any] = [:]) {
        self.name = name
        self.toolDescription = toolDescription
        self.inputSchema = inputSchema
    }
}

/// 携带 HTTP 状态码的传输层错误。
private struct StatusCarryingError: LLMHTTPErrorProviding {
    let httpStatusCode: Int?
}

// MARK: - HTTP 错误解析

@Suite("供应商 HTTP 错误解析")
struct ProviderHTTPErrorParserTests {

    @Test("OpenAI 形态的错误体解析出 message")
    func parsesOpenAIErrorBody() throws {
        let data = Data(#"{"error":{"message":"quota exceeded"}}"#.utf8)

        let error = try #require(ProviderHTTPErrorParser.parseOpenAICompatible(data: data, statusCode: 429))

        #expect(error.message == "quota exceeded")
        #expect(error.statusCode == 429)
        #expect(error.isRetryable)
    }

    @Test("Anthropic 形态的错误体解析出 message")
    func parsesAnthropicErrorBody() throws {
        let data = Data(#"{"error":{"message":"overloaded"}}"#.utf8)

        let error = try #require(ProviderHTTPErrorParser.parseAnthropicCompatible(data: data, statusCode: 529))

        #expect(error.message == "overloaded")
        #expect(error.statusCode == 529)
        #expect(error.isRetryable)
    }

    @Test("未知形态回落到通用 JSON 解析")
    func fallsBackToGenericJSON() throws {
        let data = Data(#"{"message":"flat message"}"#.utf8)

        let error = try #require(ProviderHTTPErrorParser.parseOpenAICompatible(data: data, statusCode: 400))

        #expect(error.message == "flat message")
        #expect(error.isRetryable == false)
    }

    @Test("通用 JSON 优先取 error.message")
    func genericJSONPrefersNestedErrorMessage() throws {
        let data = Data(#"{"error":{"message":"nested"},"message":"flat"}"#.utf8)

        let error = try #require(ProviderHTTPErrorParser.parseGenericJSON(data: data, statusCode: nil))

        #expect(error.message == "nested")
        #expect(error.statusCode == nil)
        #expect(error.isRetryable == false)
    }

    @Test("没有可识别字段时返回 nil")
    func returnsNilForUnrecognisedBody() {
        let data = Data(#"{"detail":"unknown"}"#.utf8)

        #expect(ProviderHTTPErrorParser.parseGenericJSON(data: data, statusCode: 500) == nil)
    }

    @Test("非 JSON 与空响应返回 nil")
    func returnsNilForNonJSONBody() {
        #expect(ProviderHTTPErrorParser.parseOpenAICompatible(data: Data("not json".utf8), statusCode: 500) == nil)
        #expect(ProviderHTTPErrorParser.parseAnthropicCompatible(data: nil, statusCode: 500) == nil)
        #expect(ProviderHTTPErrorParser.parseGenericJSON(data: nil, statusCode: 500) == nil)
    }

    @Test("仅 429 与 5xx 被视为可重试")
    func retryableStatusCodes() throws {
        func retryable(_ status: Int?) -> Bool {
            let error = ProviderHTTPErrorParser.parseGenericJSON(
                data: Data(#"{"message":"x"}"#.utf8),
                statusCode: status
            )
            return error?.isRetryable ?? false
        }

        #expect(retryable(429))
        #expect(retryable(500))
        #expect(retryable(503))
        #expect(retryable(599))
        #expect(retryable(400) == false)
        #expect(retryable(401) == false)
        #expect(retryable(404) == false)
        #expect(retryable(200) == false)
        #expect(retryable(nil) == false)
    }
}

@Suite("传输层错误状态码提取")
struct VendorLLMHTTPErrorParsingTests {

    @Test("优先读取实现 LLMHTTPErrorProviding 的错误")
    func prefersHTTPErrorProtocol() {
        let error = StatusCarryingError(httpStatusCode: 503)

        #expect(VendorLLMHTTPErrorParsing.statusCode(from: error) == 503)
    }

    @Test("回落到 NSError userInfo 中的 statusCode")
    func fallsBackToNSErrorUserInfo() {
        let error = NSError(
            domain: "test",
            code: 1,
            userInfo: ["statusCode": 429]
        )

        #expect(VendorLLMHTTPErrorParsing.statusCode(from: error) == 429)
    }

    @Test("没有状态码时返回 nil")
    func returnsNilWithoutStatusCode() {
        let error = NSError(domain: "test", code: 1, userInfo: nil)

        #expect(VendorLLMHTTPErrorParsing.statusCode(from: error) == nil)
    }
}

// MARK: - 错误类型

@Suite("LLM 服务错误")
struct LLMServiceErrorTests {

    @Test("配置类错误不可重试，请求失败可重试")
    func retryabilityClassification() {
        #expect(LLMServiceError.apiKeyEmpty.isNonRetryable)
        #expect(LLMServiceError.modelEmpty.isNonRetryable)
        #expect(LLMServiceError.providerIdEmpty.isNonRetryable)
        #expect(LLMServiceError.temperatureOutOfRange(3).isNonRetryable)
        #expect(LLMServiceError.maxTokensInvalid(0).isNonRetryable)
        #expect(LLMServiceError.providerNotFound(providerId: "x").isNonRetryable)
        #expect(LLMServiceError.invalidBaseURL("x").isNonRetryable)
        #expect(LLMServiceError.cancelled.isNonRetryable)
        #expect(LLMServiceError.requestFailed("boom").isNonRetryable == false)
    }

    @Test("错误描述覆盖全部用例")
    func errorDescriptions() {
        #expect(LLMServiceError.apiKeyEmpty.errorDescription == "API Key cannot be empty")
        #expect(LLMServiceError.modelEmpty.errorDescription == "Model name cannot be empty")
        #expect(LLMServiceError.providerIdEmpty.errorDescription == "Provider ID cannot be empty")
        #expect(
            LLMServiceError.temperatureOutOfRange(2.5).errorDescription
                == "Temperature should be between 0 and 2, current: 2.5"
        )
        #expect(
            LLMServiceError.maxTokensInvalid(-1).errorDescription
                == "Max tokens should be greater than 0, current: -1"
        )
        #expect(
            LLMServiceError.providerNotFound(providerId: "openai").errorDescription
                == "Provider not found: openai"
        )
        #expect(LLMServiceError.invalidBaseURL("ftp://x").errorDescription == "Invalid Base URL: ftp://x")
        #expect(LLMServiceError.cancelled.errorDescription == "Cancelled")
        #expect(LLMServiceError.requestFailed("boom").errorDescription == "boom")
        #expect(LLMServiceError.requestFailed("boom", statusCode: 500).errorDescription == "boom")
    }
}

@Suite("供应商承载层错误")
struct VendorAPIErrorTests {

    @Test("错误描述覆盖全部用例")
    func errorDescriptions() {
        #expect(VendorAPIError.missingAPIKey("OpenAI").errorDescription == "「OpenAI」尚未配置 API Key")
        #expect(
            VendorAPIError.apiKeyAccessFailed(provider: "OpenAI", details: "denied").errorDescription
                == "读取「OpenAI」API Key 失败：denied"
        )
        #expect(VendorAPIError.invalidBaseURL("ftp://x").errorDescription == "无效的 API 地址：ftp://x")
        #expect(VendorAPIError.emptyResponse.errorDescription == "服务返回了空响应")
        #expect(VendorAPIError.incompleteStream.errorDescription == "流式响应在收到结束信号前中断")
        #expect(
            VendorAPIError.httpStatus(statusCode: 500, summary: "boom", retryAfterSeconds: nil).errorDescription
                == "服务返回 HTTP 500：boom"
        )
        #expect(VendorAPIError.requestFailed("timeout").errorDescription == "请求失败：timeout")
        #expect(VendorAPIError.decodingFailed("bad json").errorDescription == "响应解析失败：bad json")
    }

    @Test("HTTP 错误便捷构造不带退避建议")
    func httpStatusConvenienceOverload() {
        #expect(
            VendorAPIError.httpStatus(429, "rate limited")
                == .httpStatus(statusCode: 429, summary: "rate limited", retryAfterSeconds: nil)
        )
    }

    @Test("缺失与读取失败两类错误带专属渲染类型")
    func renderKindClassification() {
        #expect(VendorAPIError.missingAPIKey("OpenAI").renderKind == LLMErrorRenderKind.apiKeyMissing)
        #expect(
            VendorAPIError.apiKeyAccessFailed(provider: "OpenAI", details: "denied").renderKind
                == LLMErrorRenderKind.apiKeyAccessFailed
        )
        #expect(VendorAPIError.requestFailed("boom").renderKind == nil)
        #expect(VendorAPIError.emptyResponse.renderKind == nil)
    }

    @Test("原始错误详情只在两类 Key 错误上提供")
    func rawErrorDetail() {
        #expect(VendorAPIError.missingAPIKey("OpenAI").rawErrorDetail == "Missing API key for: OpenAI")
        #expect(
            VendorAPIError.apiKeyAccessFailed(provider: "OpenAI", details: "denied").rawErrorDetail
                == "denied"
        )
        #expect(VendorAPIError.requestFailed("boom").rawErrorDetail == nil)
    }
}

@Suite("协议适配器错误")
struct CompatibleProviderErrorTests {

    @Test("Anthropic 适配器错误描述")
    func anthropicErrorDescriptions() {
        #expect(AnthropicCompatibleProviderError.noContent.errorDescription == "No content in response")
        #expect(
            AnthropicCompatibleProviderError.apiError(message: "boom").errorDescription == "boom"
        )
    }

    @Test("OpenAI 适配器错误描述")
    func openAIErrorDescriptions() {
        #expect(OpenAICompatibleProviderError.noChoices.errorDescription == "No choices in response")
        #expect(OpenAICompatibleProviderError.apiError(message: "boom").errorDescription == "boom")
    }
}

// MARK: - 配置与契约

@Suite("LLM 配置校验")
struct LLMConfigValidationTests {

    @Test("合法配置通过校验")
    func acceptsValidConfig() throws {
        let config = LLMConfig(model: "gpt-4o", providerId: "openai", temperature: 0.7, maxTokens: 1024)

        try config.validate()
    }

    @Test("缺省温度与 token 上限视为合法")
    func acceptsNilOptionals() throws {
        let config = LLMConfig(model: "gpt-4o", providerId: "openai")

        try config.validate()
    }

    @Test("模型名为空被拒绝")
    func rejectsEmptyModel() {
        let config = LLMConfig(model: "   ", providerId: "openai")

        #expect(throws: LLMServiceError.modelEmpty) { try config.validate() }
    }

    @Test("供应商 ID 为空被拒绝")
    func rejectsEmptyProviderID() {
        let config = LLMConfig(model: "gpt-4o", providerId: " ")

        #expect(throws: LLMServiceError.providerIdEmpty) { try config.validate() }
    }

    @Test("温度超出 0...2 被拒绝")
    func rejectsOutOfRangeTemperature() {
        #expect(throws: LLMServiceError.temperatureOutOfRange(2.5)) {
            try LLMConfig(model: "m", providerId: "p", temperature: 2.5).validate()
        }
        #expect(throws: LLMServiceError.temperatureOutOfRange(-0.5)) {
            try LLMConfig(model: "m", providerId: "p", temperature: -0.5).validate()
        }
    }

    @Test("非正的最大 token 数被拒绝")
    func rejectsNonPositiveMaxTokens() {
        #expect(throws: LLMServiceError.maxTokensInvalid(0)) {
            try LLMConfig(model: "m", providerId: "p", maxTokens: 0).validate()
        }
        #expect(throws: LLMServiceError.maxTokensInvalid(-5)) {
            try LLMConfig(model: "m", providerId: "p", maxTokens: -5).validate()
        }
    }

    @Test("默认配置指向 Anthropic")
    func defaultConfigTargetsAnthropic() {
        #expect(LLMConfig.default.providerId == "anthropic")
        #expect(LLMConfig.default.model == "claude-sonnet-4-20250514")
        #expect(LLMConfig.default.temperature == nil)
    }
}

@Suite("全局模型标识")
struct LLMModelIDTests {

    @Test("provider 与 model 都非空才可构造")
    func rejectsEmptyComponents() {
        #expect(LLMModelID(providerID: "", modelID: "m") == nil)
        #expect(LLMModelID(providerID: "p", modelID: "") == nil)
        #expect(LLMModelID(providerID: "p", modelID: "m") != nil)
    }

    @Test("原始值带固定前缀并可逆解析")
    func rawValueRoundTrips() throws {
        let id = try #require(LLMModelID(providerID: "openai", modelID: "gpt-4o"))

        #expect(id.rawValue.hasPrefix("lumi-model-v1:"))
        #expect(LLMModelID(rawValue: id.rawValue) == id)
        #expect(id.description == id.rawValue)
    }

    @Test("分隔符等特殊字符被百分号编码")
    func encodesSpecialCharacters() throws {
        let id = try #require(LLMModelID(providerID: "ns/provider", modelID: "model:v1"))

        #expect(id.rawValue.contains("%2F"))
        #expect(id.rawValue.contains("%3A"))
        #expect(LLMModelID(rawValue: id.rawValue) == id)
    }

    @Test("非法原始值返回 nil")
    func rejectsInvalidRawValues() {
        #expect(LLMModelID(rawValue: "gpt-4o") == nil)
        #expect(LLMModelID(rawValue: "lumi-model-v1:onlyone") == nil)
        #expect(LLMModelID(rawValue: "lumi-model-v1:a:b:c") == nil)
        #expect(LLMModelID(rawValue: "lumi-model-v1::m") == nil)
    }

    @Test("可编码解码")
    func codableRoundTrip() throws {
        let id = try #require(LLMModelID(providerID: "openai", modelID: "gpt-4o"))
        let data = try JSONEncoder().encode(id)

        #expect(try JSONDecoder().decode(LLMModelID.self, from: data) == id)
    }

    @Test("非法值解码抛错")
    func decodingRejectsInvalidRawValue() {
        let data = Data(#""not-a-model-id""#.utf8)

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(LLMModelID.self, from: data)
        }
    }
}

@Suite("供应商元数据")
struct LLMProviderInfoTests {

    @Test("模型 id 列表与包含判定")
    func modelIDHelpers() {
        let info = LLMProviderInfo(
            id: "openai",
            displayName: "OpenAI",
            defaultModel: "gpt-4o",
            models: [
                LLMModelInfo(id: "gpt-4o"),
                LLMModelInfo(id: "gpt-4o-mini"),
            ]
        )

        #expect(info.modelIDs == ["gpt-4o", "gpt-4o-mini"])
        #expect(info.contains(model: "gpt-4o"))
        #expect(info.contains(model: "gpt-3.5") == false)
    }

    @Test("供应商类型按是否本地推导")
    func providerTypeIsInferred() {
        let cloud = LLMProviderInfo(id: "openai", displayName: "OpenAI", defaultModel: "m", models: [])
        let local = LLMProviderInfo(id: "lmstudio", displayName: "LM Studio", defaultModel: "m", models: [], isLocal: true)

        #expect(cloud.providerType == .cloudService)
        #expect(local.providerType == .local)
    }

    @Test("显式声明的供应商类型优先")
    func explicitProviderTypeWins() {
        let info = LLMProviderInfo(
            id: "relay",
            displayName: "Relay",
            defaultModel: "m",
            models: [],
            providerType: .relay
        )

        #expect(info.providerType == .relay)
    }

    @Test("缺省协议为 OpenAI 兼容")
    func defaultAPIFormatIsOpenAI() {
        let info = LLMProviderInfo(id: "x", displayName: "X", defaultModel: "m", models: [])

        #expect(info.apiFormat == .openAI)
        #expect(info.apiKeyStorageKey == "")
        #expect(info.description == "")
        #expect(info.websiteURL == nil)
    }

    @Test("供应商类型的展示名与图标")
    func providerTypePresentation() {
        #expect(LLMProviderType.cloudService.displayName == "云服务商")
        #expect(LLMProviderType.relay.displayName == "中转站")
        #expect(LLMProviderType.local.displayName == "本地")
        #expect(LLMProviderType.cloudService.systemImage == "cloud")
        #expect(LLMProviderType.relay.systemImage == "arrow.triangle.branch")
        #expect(LLMProviderType.local.systemImage == "cpu")
    }

    @Test("模型元数据的缺省值")
    func modelInfoDefaults() {
        let model = LLMModelInfo(id: "gpt-4o")

        #expect(model.displayName == "gpt-4o")
        #expect(model.contextWindowSize == nil)
        #expect(model.supportsStreaming)
        #expect(model.supportsVision == false)
        #expect(model.supportsTools)
        #expect(LLMModelInfo(id: "x", displayName: "X").displayName == "X")
    }
}

@Suite("模型下载状态")
struct LLMModelDownloadStateTests {

    @Test("进度缺省值")
    func progressDefaults() {
        let progress = LLMModelDownloadProgress()

        #expect(progress.fractionCompleted == 0)
        #expect(progress.completedFiles == 0)
        #expect(progress.totalFiles == 0)
        #expect(progress.downloadedBytes == 0)
        #expect(progress.totalBytes == 0)
        #expect(progress.speedBytesPerSecond == nil)
    }

    @Test("状态缺省值")
    func stateDefaults() {
        let state = LLMModelDownloadState()

        #expect(state.status == .idle)
        #expect(state.modelID == nil)
        #expect(state.downloadedModelIDs.isEmpty)
        #expect(state.cacheSizeBytes == 0)
        #expect(state.speedLimitBytesPerSecond == nil)
        #expect(state.currentFileName == nil)
    }

    @Test("失败状态携带原因")
    func failedStatusCarriesReason() {
        let state = LLMModelDownloadState(status: .failed("network"))

        #expect(state.status == .failed("network"))
    }
}

@Suite("工具名转义映射")
struct LLMToolNameReverseMapTests {

    @Test("映射建立 sanitize 名到原始名")
    func buildsReverseMap() {
        let tools: [any LLMToolSchemaProviding] = [
            FakeToolSchema(name: "app-store.list"),
            FakeToolSchema(name: "read_file"),
        ]

        let map = LLMToolNameSanitizer.reverseMap(for: tools)

        // 短横线是合法字符，只有点号会被换成下划线。
        #expect(map["app-store_list"] == "app-store.list")
        #expect(map["read_file"] == "read_file")
    }

    @Test("同名冲突时先注册者优先")
    func firstRegistrationWins() {
        let tools: [any LLMToolSchemaProviding] = [
            FakeToolSchema(name: "a.b"),
            FakeToolSchema(name: "a b"),
        ]

        let map = LLMToolNameSanitizer.reverseMap(for: tools)

        #expect(map.count == 1)
        #expect(map["a_b"] == "a.b")
    }

    @Test("首字符非字母时补 tool_ 前缀")
    func addsToolPrefixWhenFirstCharacterIsNotLetter() {
        let tools: [any LLMToolSchemaProviding] = [
            FakeToolSchema(name: "1.tool"),
        ]

        let map = LLMToolNameSanitizer.reverseMap(for: tools)

        #expect(map["tool_1_tool"] == "1.tool")
    }

    @Test("空列表得到空映射")
    func emptyToolListYieldsEmptyMap() {
        #expect(LLMToolNameSanitizer.reverseMap(for: []).isEmpty)
    }
}
