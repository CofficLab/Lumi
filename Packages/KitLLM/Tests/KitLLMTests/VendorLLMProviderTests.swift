import Foundation
import Testing
@testable import KitLLM

/// VendorLLMProvider 的静态供应商默认行为。
struct VendorLLMProviderTests {

    @Test("静态供应商:usesRemoteModelList==false, availableModels==静态列表, refresh 无害")
    @MainActor
    func staticProviderBehavior() async {
        let provider = StaticTestProvider()
        #expect(provider.usesRemoteModelList == false)
        #expect(provider.availableModels.map(\.id) == ["static-a", "static-b"])
        #expect(provider.lastModelSyncDate == nil)

        // 静态供应商 refreshModels 不抛错、不改列表
        try? await provider.refreshModels()
        #expect(provider.availableModels.map(\.id) == ["static-a", "static-b"])
    }
}

/// 最小静态供应商测试替身。
@MainActor
private final class StaticTestProvider: VendorLLMProvider {
    init() {
        super.init(info: LLMProviderInfo(
            id: "static-test",
            displayName: "Static Test",
            defaultModel: "static-a",
            models: [
                LLMModelInfo(id: "static-a"),
                LLMModelInfo(id: "static-b"),
            ]
        ))
    }
}