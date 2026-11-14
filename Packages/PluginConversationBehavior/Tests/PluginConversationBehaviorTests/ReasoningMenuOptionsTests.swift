import Foundation
import KitLLM
import Testing
import ProviderConversation
@testable import PluginConversationBehavior

/// 推理弹层按模型能力裁剪的行为。
///
/// 「关闭思考」在不同模型上语义不同：能真关的直接生效，强制思考的降为最低
/// 档位，既不能关也不认档位的模型只保留关闭项并说明原因。
@Suite("推理菜单能力裁剪")
struct ReasoningMenuOptionsTests {

    @Test("模型未声明能力时保持通用行为")
    func defaultsWhenCapabilityMissing() {
        let options = ReasoningMenuOptions.make(capability: nil)

        #expect(options.efforts == ReasoningEffort.allCases)
        #expect(options.off == .available)
    }

    @Test("强制思考的模型：档位按声明过滤，关闭降为最低档")
    func alwaysThinkingModel() {
        let capability = LLMReasoningCapability(
            supportedEfforts: ["low", "medium", "high", "xhigh", "max"],
            offStrategy: .lowestEffort("low")
        )
        let options = ReasoningMenuOptions.make(capability: capability)

        #expect(options.efforts == ReasoningEffort.allCases)
        #expect(options.off == .degradedToEffort(.low))
    }

    @Test("支持关闭的模型：关闭可用，档位按声明过滤")
    func disableableModel() {
        let capability = LLMReasoningCapability(
            supportedEfforts: [],
            offStrategy: .disableThinkingParameter
        )
        let options = ReasoningMenuOptions.make(capability: capability)

        #expect(options.efforts.isEmpty)
        #expect(options.off == .available)
    }

    @Test("关不掉思考的模型：关闭项不可用")
    func undisableableModel() {
        let capability = LLMReasoningCapability(
            supportedEfforts: [],
            offStrategy: .omitParameters
        )
        let options = ReasoningMenuOptions.make(capability: capability)

        #expect(options.efforts.isEmpty)
        #expect(options.off == .unsupported)
    }

    @Test("只暴露模型声明支持的档位")
    func filtersUnsupportedEfforts() {
        let capability = LLMReasoningCapability(
            supportedEfforts: ["low", "medium"],
            offStrategy: .lowestEffort("low")
        )
        let options = ReasoningMenuOptions.make(capability: capability)

        #expect(options.efforts == [.low, .medium])
    }

    @Test("强制思考的模型上关闭显示真实档位")
    func effectiveEffortReflectsDegradation() {
        let capability = LLMReasoningCapability(
            supportedEfforts: ["low", "medium", "high", "xhigh", "max"],
            offStrategy: .lowestEffort("low")
        )
        let options = ReasoningMenuOptions.make(capability: capability)

        #expect(options.effectiveEffort(for: nil) == .low)
        #expect(options.effectiveEffort(for: .high) == .high)
    }

    @Test("可关闭的模型上关闭就是关闭")
    func effectiveEffortKeepsOff() {
        let capability = LLMReasoningCapability(
            supportedEfforts: [],
            offStrategy: .disableThinkingParameter
        )
        let options = ReasoningMenuOptions.make(capability: capability)

        #expect(options.effectiveEffort(for: nil) == nil)
    }
}
