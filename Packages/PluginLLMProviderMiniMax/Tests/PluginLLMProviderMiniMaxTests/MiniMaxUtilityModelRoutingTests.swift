import Foundation
import KitLLM
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderMiniMax

/// MiniMax 声明的轻量任务模型在管理器路由层的实际行为。
///
/// 背景：`LLMProviderInfo.recommendedUtilityModel` 是「幕后任务用哪个模型」
/// 的唯一事实来源。对话标题、上下文摘要都通过
/// `LLMManaging.utilityModelRoute(for:)` 解析它。
///
/// 关键约束：**声明的模型必须真的在模型池中**。否则
/// `utilityModelRoute` 会因「不在动态模型池中」而返回 `nil`，静默回退到
/// 对话主模型——声明形同虚设，而且没有任何报错。
@MainActor
struct MiniMaxUtilityModelRoutingTests {

    @Test("声明的轻量任务模型能被管理器解析出路由")
    func utilityRouteResolvesToFlash() throws {
        let manager = DefaultLLMManager()
        try manager.register(MiniMaxOpenAIProvider())

        let route = try #require(manager.utilityModelRoute(for: "minimax-tokenplan"))

        #expect(route.providerID == "minimax-tokenplan")
        #expect(route.modelName == "MiniMax-M3.1-Flash")
        // 轻量模型的上下文窗口决定摘要请求的输入预算，不能落 32K 兜底。
        #expect(route.modelInfo.contextWindowSize == 1_000_000)
    }

    @Test("轻量任务模型确实在动态模型池中（否则路由会静默回退）")
    func utilityModelIsInDynamicModelPool() throws {
        let manager = DefaultLLMManager()
        let provider = MiniMaxOpenAIProvider()
        try manager.register(provider)

        let declared = try #require(provider.providerInfo.recommendedUtilityModel)
        #expect(
            manager.contains(model: declared, in: provider),
            "声明的轻量模型 \(declared) 不在模型池中，路由会静默回退到主模型"
        )
    }

    @Test("未刷新远程列表时路由依然可用（离线兜底）")
    func utilityRouteWorksWithoutRemoteRefresh() throws {
        let manager = DefaultLLMManager()
        let provider = MiniMaxOpenAIProvider()
        try manager.register(provider)

        // 未调用 refreshModels，模型池 = 静态清单
        #expect(provider.lastModelSyncDate == nil)

        let route = try #require(manager.utilityModelRoute(for: "minimax-tokenplan"))
        #expect(route.modelName == "MiniMax-M3.1-Flash")
    }
}
