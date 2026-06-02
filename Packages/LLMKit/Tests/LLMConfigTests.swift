import Testing
import Foundation
@testable import LLMKit

@Suite("LLMConfig Tests")
struct LLMConfigTests {

    // MARK: - 构造

    @Test("默认配置使用 anthropic 供应商")
    func defaultConfig() {
        let config = LLMConfig.default
        #expect(config.apiKey == "")
        #expect(config.model == "claude-sonnet-4-20250514")
        #expect(config.providerId == "anthropic")
        #expect(config.temperature == nil)
        #expect(config.maxTokens == nil)
    }

    @Test("自定义构造")
    func customInit() {
        let config = LLMConfig(
            apiKey: "sk-test",
            model: "gpt-4o",
            providerId: "openai",
            temperature: 0.7,
            maxTokens: 4096
        )
        #expect(config.apiKey == "sk-test")
        #expect(config.model == "gpt-4o")
        #expect(config.providerId == "openai")
        #expect(config.temperature == 0.7)
        #expect(config.maxTokens == 4096)
    }

    // MARK: - Equatable

    @Test("Equatable 相等")
    func equality() {
        let a = LLMConfig(apiKey: "k", model: "m", providerId: "p")
        let b = LLMConfig(apiKey: "k", model: "m", providerId: "p")
        #expect(a == b)
    }

    @Test("Equatable 不等 - apiKey 不同")
    func inequalityApiKey() {
        let a = LLMConfig(apiKey: "k1", model: "m", providerId: "p")
        let b = LLMConfig(apiKey: "k2", model: "m", providerId: "p")
        #expect(a != b)
    }

    @Test("Equatable 不等 - temperature 不同")
    func inequalityTemperature() {
        let a = LLMConfig(apiKey: "k", model: "m", providerId: "p", temperature: 0.5)
        let b = LLMConfig(apiKey: "k", model: "m", providerId: "p", temperature: 1.0)
        #expect(a != b)
    }

    // MARK: - validate()

    @Test("validate 通过 - 完整配置")
    func validateSuccess() throws {
        let config = LLMConfig(apiKey: "sk-test", model: "gpt-4o", providerId: "openai")
        #expect(throws: Never.self) { try config.validate() }
    }

    @Test("validate 失败 - 空 API Key")
    func validateEmptyApiKey() {
        let config = LLMConfig(apiKey: "  ", model: "m", providerId: "p")
        #expect(throws: LLMServiceError.apiKeyEmpty) { try config.validate() }
    }

    @Test("validate 失败 - 空模型名")
    func validateEmptyModel() {
        let config = LLMConfig(apiKey: "k", model: "", providerId: "p")
        #expect(throws: LLMServiceError.modelEmpty) { try config.validate() }
    }

    @Test("validate 失败 - 空供应商 ID")
    func validateEmptyProviderId() {
        let config = LLMConfig(apiKey: "k", model: "m", providerId: "  ")
        #expect(throws: LLMServiceError.providerIdEmpty) { try config.validate() }
    }

    @Test("validate 失败 - 温度 < 0")
    func validateTemperatureTooLow() {
        let config = LLMConfig(apiKey: "k", model: "m", providerId: "p", temperature: -0.1)
        #expect {
            try config.validate()
        } throws: { error in
            guard let e = error as? LLMServiceError,
                  case .temperatureOutOfRange(let v) = e else { return false }
            return v == -0.1
        }
    }

    @Test("validate 失败 - 温度 > 2")
    func validateTemperatureTooHigh() {
        let config = LLMConfig(apiKey: "k", model: "m", providerId: "p", temperature: 2.5)
        #expect {
            try config.validate()
        } throws: { error in
            guard let e = error as? LLMServiceError,
                  case .temperatureOutOfRange(let v) = e else { return false }
            return v == 2.5
        }
    }

    @Test("validate 通过 - 温度边界 0 和 2")
    func validateTemperatureBoundaries() throws {
        let lo = LLMConfig(apiKey: "k", model: "m", providerId: "p", temperature: 0.0)
        let hi = LLMConfig(apiKey: "k", model: "m", providerId: "p", temperature: 2.0)
        #expect(throws: Never.self) { try lo.validate() }
        #expect(throws: Never.self) { try hi.validate() }
    }

    @Test("validate 失败 - maxTokens <= 0")
    func validateMaxTokensInvalid() {
        let config = LLMConfig(apiKey: "k", model: "m", providerId: "p", maxTokens: 0)
        #expect {
            try config.validate()
        } throws: { error in
            guard let e = error as? LLMServiceError,
                  case .maxTokensInvalid(let v) = e else { return false }
            return v == 0
        }
    }

    @Test("validate 通过 - maxTokens 正值")
    func validateMaxTokensValid() throws {
        let config = LLMConfig(apiKey: "k", model: "m", providerId: "p", maxTokens: 4096)
        #expect(throws: Never.self) { try config.validate() }
    }

    @Test("validate 通过 - nil temperature 和 nil maxTokens")
    func validateNilOptionals() throws {
        let config = LLMConfig(apiKey: "k", model: "m", providerId: "p")
        #expect(throws: Never.self) { try config.validate() }
    }
}
