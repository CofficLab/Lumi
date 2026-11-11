import Foundation
import KitLLM
import Testing
@testable import ProviderLLMManager

/// 可声明轻量任务模型的最小供应商，用于验证 `utilityModelRoute(for:)` 的校验逻辑。
@MainActor
private final class UtilityDeclarationProvider: SuperLLMProvider {
    let providerInfo: LLMProviderInfo
    var availableModels: [LLMModelInfo]

    init(
        id: String = "utility-provider",
        models: [LLMModelInfo],
        defaultModel: String,
        recommendedUtilityModel: String?
    ) {
        self.providerInfo = LLMProviderInfo(
            id: id,
            displayName: id,
            defaultModel: defaultModel,
            models: models,
            recommendedUtilityModel: recommendedUtilityModel
        )
        self.availableModels = models
    }

    var providerID: String { providerInfo.id }

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        LLMResponse(content: "ok", model: request.model)
    }
}

/// #1157：供应商声明的轻量任务模型路由校验。
@MainActor
struct UtilityModelRouteTests {

    @Test("有效声明返回轻量模型路由")
    func validDeclarationReturnsUtilityRoute() throws {
        let manager = DefaultLLMManager()
        let provider = UtilityDeclarationProvider(
            models: [
                LLMModelInfo(id: "main-model", contextWindowSize: 200_000),
                LLMModelInfo(id: "utility-model", contextWindowSize: 32_000),
            ],
            defaultModel: "main-model",
            recommendedUtilityModel: "utility-model"
        )
        try manager.register(provider)

        let route = try #require(manager.utilityModelRoute(for: "utility-provider"))
        #expect(route.modelName == "utility-model")
        #expect(route.providerID == "utility-provider")
        #expect(route.modelInfo.contextWindowSize == 32_000)
    }

    @Test("未声明轻量模型时返回 nil")
    func missingDeclarationReturnsNil() throws {
        let manager = DefaultLLMManager()
        let provider = UtilityDeclarationProvider(
            models: [LLMModelInfo(id: "main-model")],
            defaultModel: "main-model",
            recommendedUtilityModel: nil
        )
        try manager.register(provider)

        #expect(manager.utilityModelRoute(for: "utility-provider") == nil)
    }

    @Test("声明为空字符串时返回 nil")
    func emptyDeclarationReturnsNil() throws {
        let manager = DefaultLLMManager()
        let provider = UtilityDeclarationProvider(
            models: [LLMModelInfo(id: "main-model")],
            defaultModel: "main-model",
            recommendedUtilityModel: ""
        )
        try manager.register(provider)

        #expect(manager.utilityModelRoute(for: "utility-provider") == nil)
    }

    @Test("声明的模型不在模型池中时返回 nil")
    func declarationOutsidePoolReturnsNil() throws {
        let manager = DefaultLLMManager()
        let provider = UtilityDeclarationProvider(
            models: [LLMModelInfo(id: "main-model")],
            defaultModel: "main-model",
            recommendedUtilityModel: "ghost-model"
        )
        try manager.register(provider)

        #expect(manager.utilityModelRoute(for: "utility-provider") == nil)
    }

    @Test("远程刷新下线推荐模型后回退 nil")
    func retiredRemoteUtilityModelReturnsNil() throws {
        let manager = DefaultLLMManager()
        let provider = UtilityDeclarationProvider(
            models: [
                LLMModelInfo(id: "main-model"),
                LLMModelInfo(id: "utility-model"),
            ],
            defaultModel: "main-model",
            recommendedUtilityModel: "utility-model"
        )
        try manager.register(provider)
        #expect(manager.utilityModelRoute(for: "utility-provider") != nil)

        // 模拟远程刷新后轻量模型下线：动态池不再包含它。
        provider.availableModels = [LLMModelInfo(id: "main-model")]
        #expect(manager.utilityModelRoute(for: "utility-provider") == nil)
    }

    @Test("未注册供应商返回 nil")
    func unknownProviderReturnsNil() {
        let manager = DefaultLLMManager()
        #expect(manager.utilityModelRoute(for: "does-not-exist") == nil)
    }
}