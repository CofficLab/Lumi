import Foundation
import LumiCoreKit
import Testing

@Suite struct LumiModelVisionSupportTests {
    private let textOnlyProvider = LumiLLMProviderInfo(
        id: "demo",
        displayName: "Demo",
        defaultModel: "text-model",
        availableModels: ["text-model", "vision-model"],
        modelCapabilities: [
            "text-model": .init(supportsVision: false, supportsTools: true),
            "vision-model": .init(supportsVision: true, supportsTools: true),
        ],
        websiteURL: URL(string: "https://example.com")!
    )

    @Test func allowsImagesInAutoRoutingMode() {
        #expect(
            LumiModelVisionSupport.supportsVision(
                providerInfos: [textOnlyProvider],
                routingMode: .auto,
                providerID: "demo",
                model: "text-model"
            )
        )
    }

    @Test func blocksTextOnlyModelInManualMode() {
        #expect(
            !LumiModelVisionSupport.supportsVision(
                providerInfos: [textOnlyProvider],
                routingMode: .manual,
                providerID: "demo",
                model: "text-model"
            )
        )
    }

    @Test func allowsVisionModelInManualMode() {
        #expect(
            LumiModelVisionSupport.supportsVision(
                providerInfos: [textOnlyProvider],
                routingMode: .manual,
                providerID: "demo",
                model: "vision-model"
            )
        )
    }

    @Test func allowsWhenCapabilityMetadataIsMissing() {
        let provider = LumiLLMProviderInfo(
            id: "legacy",
            displayName: "Legacy",
            defaultModel: "legacy-model",
            availableModels: ["legacy-model"],
            websiteURL: URL(string: "https://example.com")!
        )

        #expect(
            LumiModelVisionSupport.supportsVision(
                providerInfos: [provider],
                routingMode: .manual,
                providerID: "legacy",
                model: "legacy-model"
            )
        )
    }
}
