import Foundation
import LumiUI
import ProviderMessage
import SwiftUI
import Testing
@testable import PluginMessageRenderer

/// V5（ChatGPT）reasoning 呈现规格测试。
///
/// 基准是 V5 方案第 2.6 节：
/// - 标题为「正在思考…」或「已思考」；
/// - 有**真实**时长时才显示时长；
/// - 完成后默认收起，但用户的显式选择优先。
@Suite("V5 reasoning 规格")
struct ChatGPTReasoningViewTests {

    @Test("空文本不渲染")
    func emptyTextDoesNotRender() {
        #expect(!ChatGPTReasoningStyle.shouldRender(text: "", isStreaming: false))
        #expect(!ChatGPTReasoningStyle.shouldRender(text: "   \n\t ", isStreaming: true))
        #expect(ChatGPTReasoningStyle.shouldRender(text: "思考中", isStreaming: true))
    }

    @Test("摘要是最后一个非空行")
    func summaryIsLastNonEmptyLine() {
        let text = "第一行\n\n  第二行  \n第三行"
        #expect(ChatGPTReasoningStyle.summary(text: text) == "第三行")
        #expect(ChatGPTReasoningStyle.summary(text: "   \n  ") == nil)
    }

    @Test("没有真实时长字段时不显示时长")
    func durationRequiresRealField() {
        #expect(ChatGPTReasoningStyle.durationText(durationMilliseconds: nil) == nil)
        #expect(ChatGPTReasoningStyle.durationText(durationMilliseconds: 0) == nil)
        #expect(ChatGPTReasoningStyle.durationText(durationMilliseconds: -100) == nil)
    }

    @Test("真实时长按秒或毫秒格式化")
    func durationFormatting() {
        #expect(ChatGPTReasoningStyle.durationText(durationMilliseconds: 350) == "350ms")
        #expect(ChatGPTReasoningStyle.durationText(durationMilliseconds: 1500) == "1.5s")
    }

    @Test("完成后自动收起，但用户的显式选择优先")
    func autoCollapseRespectsExplicitChoice() {
        var state = ChatGPTReasoningCollapseState()
        #expect(!state.isExpanded)

        // 完成时的自动收起：默认就是收起。
        state.applyAutoCollapseOnCompletion()
        #expect(!state.isExpanded)

        // 用户显式展开后，自动收起**不生效**。
        state.setExpanded(true)
        state.applyAutoCollapseOnCompletion()
        #expect(state.isExpanded)
        #expect(state.hasExplicitChoice)
    }

    @Test("用户显式收起后不会被自动展开")
    func explicitCollapseIsSticky() {
        var state = ChatGPTReasoningCollapseState()
        state.setExpanded(true)
        state.setExpanded(false)
        state.applyAutoCollapseOnCompletion()
        #expect(!state.isExpanded)
    }

    @Test("几何符合 V5 token")
    func metrics() {
        #expect(ChatGPTReasoningStyle.contentMaxHeight == 240)
        #expect(ChatGPTReasoningStyle.brainIconSize == 16)
        #expect(ChatGPTReasoningStyle.titleFontSize == 13)
        #expect(ChatGPTReasoningStyle.durationFontSize == 11)
    }
}
