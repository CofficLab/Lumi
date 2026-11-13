import Foundation
import Testing
@testable import KitLLM

/// 「关闭思考」在请求体里的映射规则。
///
/// 关闭思考在不同模型上语义不同：能真关的下发关闭参数，强制思考的降为最低
/// 档位，既不能关也不认档位的什么都不下发。省略档位 ≠ 关闭——省略会让服务端
/// 用自己的默认档位（MiniMax-M3.1-Flash 即为 max）。
struct ReasoningOffRequestTests {

    private func config(
        effort: String? = nil,
        off: Bool = false,
        capability: LLMReasoningCapability? = nil
    ) -> LLMConfig {
        LLMConfig(
            model: "MiniMax-M3.1-Flash",
            providerId: "minimax-tokenplan",
            reasoningEffort: effort,
            reasoningOff: off,
            reasoningCapability: capability
        )
    }

    private func body(
        config: LLMConfig,
        model: String = "MiniMax-M3.1-Flash"
    ) -> [String: Any] {
        var body: [String: Any] = [:]
        OpenAICompatibleGenerationOptionsApplier.apply(
            config: config,
            model: model,
            additionalReasoningEfforts: ["xhigh", "max"],
            to: &body
        )
        return body
    }

    @Test("关闭思考在强制思考的模型上降为最低档位")
    func offDegradesToLowestEffort() {
        let capability = LLMReasoningCapability(
            supportedEfforts: ["low", "medium", "high", "xhigh", "max"],
            offStrategy: .lowestEffort("low")
        )
        let body = body(config: config(off: true, capability: capability))

        #expect(body["reasoning_effort"] as? String == "low")
        #expect(body["thinking"] == nil)
    }

    @Test("关闭思考在支持关闭的模型上下发关闭参数")
    func offDisablesThinkingParameter() {
        let capability = LLMReasoningCapability(
            supportedEfforts: [],
            offStrategy: .disableThinkingParameter
        )
        let body = body(config: config(off: true, capability: capability), model: "MiniMax-M3")

        #expect((body["thinking"] as? [String: String])?["type"] == "disabled")
        #expect(body["reasoning_effort"] == nil)
    }

    @Test("关不掉思考的模型不下发任何推理参数")
    func offOnUndisableableModelSendsNothing() {
        let capability = LLMReasoningCapability(
            supportedEfforts: [],
            offStrategy: .omitParameters
        )
        let body = body(config: config(off: true, capability: capability), model: "MiniMax-M2.7")

        #expect(body["reasoning_effort"] == nil)
        #expect(body["thinking"] == nil)
    }

    @Test("模型未声明能力时关闭不下发参数")
    func offWithoutCapabilitySendsNothing() {
        let body = body(config: config(off: true, capability: nil))

        #expect(body["reasoning_effort"] == nil)
        #expect(body["thinking"] == nil)
    }

    @Test("档位超出模型声明范围时不下发")
    func effortOutsideDeclaredRangeIsDropped() {
        let capability = LLMReasoningCapability(
            supportedEfforts: ["low", "medium", "high"],
            offStrategy: .lowestEffort("low")
        )
        #expect(body(config: config(effort: "high", capability: capability))["reasoning_effort"] as? String == "high")
        #expect(body(config: config(effort: "max", capability: capability))["reasoning_effort"] == nil)
    }

    @Test("模型声明支持的额外档位仍可下发")
    func extraEffortIsForwarded() {
        let capability = LLMReasoningCapability(
            supportedEfforts: ["low", "medium", "high", "xhigh", "max"],
            offStrategy: .lowestEffort("low")
        )
        let body = body(config: config(effort: "xhigh", capability: capability))

        #expect(body["reasoning_effort"] as? String == "xhigh")
    }
}
