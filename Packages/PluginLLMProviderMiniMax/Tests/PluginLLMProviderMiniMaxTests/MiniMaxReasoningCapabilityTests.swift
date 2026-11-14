import Foundation
import KitLLM
import Testing
@testable import PluginLLMProviderMiniMax

/// MiniMax 模型的思考能力声明。
///
/// 官方文档（2026-11 `platform.minimaxi.com/docs/api-reference/text-chat-openai`）：
/// - M3.1-Flash 强制开启思考，`thinking: {"type": "disabled"}` / `effort: "none"`
///   会返回 400；思考深度用 `reasoning_effort`（low/medium/high/xhigh/max，
///   省略时默认 `max`）。
/// - M3 默认开启 adaptive thinking，`thinking: {"type": "disabled"}` 可真正关闭；
///   `reasoning_effort` 只对 M3.1-Flash 生效。
/// - M2.x 思考无法关闭（传入 disabled 被接受但不生效）。
@Suite("MiniMax 思考能力声明")
struct MiniMaxReasoningCapabilityTests {

    @Test("M3.1 强制思考：五档可调，关闭降为最低档")
    func m31IsAlwaysThinking() throws {
        let capability = try #require(
            MiniMaxModelFamily.reasoningCapability(for: "MiniMax-M3.1-Flash")
        )
        #expect(capability.supportedEfforts == ["low", "medium", "high", "xhigh", "max"])
        #expect(capability.offStrategy == .lowestEffort("low"))
        #expect(!capability.supportsDisabling)
        #expect(capability.degradesToLowestEffort)
    }

    @Test("M3 可关闭思考，但不支持档位调节")
    func m3SupportsDisabling() throws {
        let capability = try #require(
            MiniMaxModelFamily.reasoningCapability(for: "MiniMax-M3")
        )
        #expect(capability.supportedEfforts.isEmpty)
        #expect(capability.offStrategy == .disableThinkingParameter)
        #expect(capability.supportsDisabling)
    }

    @Test("M2 系列关不掉思考", arguments: [
        "MiniMax-M2",
        "MiniMax-M2.7",
    ])
    func m2CannotDisableThinking(_ modelID: String) throws {
        let capability = try #require(
            MiniMaxModelFamily.reasoningCapability(for: modelID)
        )
        #expect(capability.supportedEfforts.isEmpty)
        #expect(capability.offStrategy == .omitParameters)
        #expect(!capability.supportsDisabling)
    }

    @Test("未知模型不声明思考能力")
    func unknownModelDeclaresNothing() {
        #expect(MiniMaxModelFamily.reasoningCapability(for: "gpt-4o") == nil)
    }

    @Test("静态清单带上思考能力")
    func staticCatalogCarriesCapability() throws {
        let flash = try #require(
            MiniMaxVendorModels.all.first { $0.id == "MiniMax-M3.1-Flash" }
        )
        #expect(flash.reasoning?.offStrategy == .lowestEffort("low"))

        let m3 = try #require(
            MiniMaxVendorModels.all.first { $0.id == "MiniMax-M3" }
        )
        #expect(m3.reasoning?.offStrategy == .disableThinkingParameter)
    }

    @Test("远程新增模型按家族补全思考能力")
    func remoteModelGetsCapability() throws {
        let merged = MiniMaxRemoteModelListLoader.merge(
            base: MiniMaxVendorModels.all,
            remote: [MiniMaxModelFamily.enriched("MiniMax-M3.1-Flash-Preview")]
        )
        let added = try #require(
            merged.first { $0.id == "MiniMax-M3.1-Flash-Preview" }
        )
        #expect(added.reasoning?.offStrategy == .lowestEffort("low"))
    }

    @Test("退役标记不丢失思考能力")
    func retiredModelKeepsCapability() throws {
        let merged = MiniMaxRemoteModelListLoader.merge(
            base: MiniMaxVendorModels.all,
            remote: [MiniMaxModelFamily.enriched("MiniMax-M3")]
        )
        let retired = try #require(
            merged.first { $0.id == "MiniMax-M3.1-Flash" }
        )
        #expect(retired.isRetired)
        #expect(retired.reasoning?.offStrategy == .lowestEffort("low"))
    }
}
