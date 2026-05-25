import Testing
import Foundation
@testable import LLMKit

@Suite("LLMProviderInfo Tests")
struct LLMProviderInfoTests {

    @Test("构造与属性读取")
    func construction() {
        let info = LLMProviderInfo(
            id: "openai",
            displayName: "OpenAI",
            shortName: "OA",
            description: "GPT models",
            websiteURL: "https://openai.com",
            availableModels: ["gpt-4o", "gpt-4o-mini"],
            defaultModel: "gpt-4o",
            isLocal: false,
            isEnabled: true,
            contextWindowSizes: ["gpt-4o": 128_000]
        )
        #expect(info.id == "openai")
        #expect(info.displayName == "OpenAI")
        #expect(info.shortName == "OA")
        #expect(info.description == "GPT models")
        #expect(info.websiteURL == "https://openai.com")
        #expect(info.availableModels == ["gpt-4o", "gpt-4o-mini"])
        #expect(info.defaultModel == "gpt-4o")
        #expect(info.isLocal == false)
        #expect(info.isEnabled == true)
        #expect(info.contextWindowSizes == ["gpt-4o": 128_000])
    }

    @Test("Equatable 相等")
    func equality() {
        let a = makeInfo(id: "x")
        let b = makeInfo(id: "x")
        #expect(a == b)
    }

    @Test("Equatable 不等 - id 不同")
    func inequalityId() {
        let a = makeInfo(id: "a")
        let b = makeInfo(id: "b")
        #expect(a != b)
    }

    @Test("Identifiable id 属性")
    func identifiable() {
        let info = makeInfo(id: "test")
        #expect(info.id == "test")
    }

    @Test("可选字段为 nil")
    func nilOptionals() {
        let info = LLMProviderInfo(
            id: "local",
            displayName: "Local",
            shortName: "LC",
            description: "",
            websiteURL: nil,
            availableModels: [],
            defaultModel: "",
            isLocal: true,
            isEnabled: true,
            contextWindowSizes: [:]
        )
        #expect(info.websiteURL == nil)
        #expect(info.availableModels.isEmpty)
    }

    // MARK: - Helper

    private func makeInfo(id: String) -> LLMProviderInfo {
        LLMProviderInfo(
            id: id,
            displayName: "Test",
            shortName: "TT",
            description: "Desc",
            websiteURL: nil,
            availableModels: ["m1"],
            defaultModel: "m1",
            isLocal: false,
            isEnabled: true,
            contextWindowSizes: [:]
        )
    }
}
