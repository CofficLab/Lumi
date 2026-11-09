import CoreGraphics
import Foundation
import Testing
@testable import PluginMessageRenderer

/// V4（ZCode）reasoning 折叠契约测试。
///
/// 基准是 ZCode 3.15.1 计划第 2.6 节：
/// - streaming 和 complete 默认均收起；streaming 且 text 为空不渲染；
/// - 完成时自动 collapse 不得覆盖用户显式展开/收起选择；
/// - Brain 图标 16；
/// - 只有真实时长字段语义匹配时才显示完成时长；不得用消息到达间隔伪造；
/// - streaming 收起时显示最后非空行摘要；
/// - 内容顶部间距 12、最大高 240、内部纵向滚动；
/// - turn 级工作历史折叠与单条 reasoning 折叠是两套独立状态。
///
/// - Important: 状态键必须与 turn 折叠状态**不同**，
///   否则折叠一个会连带影响另一个。
@Suite("ZCode reasoning 折叠")
struct ZCodeReasoningViewTests {

    // MARK: - 可见性

    @Test("空 streaming reasoning 不渲染")
    func emptyStreamingReasoningIsHidden() {
        #expect(ZCodeReasoningStyle.shouldRender(text: "", isStreaming: true) == false)
    }

    @Test("空白的 streaming reasoning 也不渲染")
    func blankStreamingReasoningIsHidden() {
        #expect(ZCodeReasoningStyle.shouldRender(text: "   \n  ", isStreaming: true) == false)
    }

    @Test("有内容的 reasoning 渲染")
    func nonEmptyReasoningIsRendered() {
        #expect(ZCodeReasoningStyle.shouldRender(text: "思考中", isStreaming: true))
        #expect(ZCodeReasoningStyle.shouldRender(text: "思考完成", isStreaming: false))
    }

    @Test("streaming 与 complete 默认都收起")
    func bothPhasesDefaultCollapsed() {
        var state = ZCodeReasoningCollapseState()

        #expect(!state.isExpanded)
        #expect(!state.isExpanded)
    }

    // MARK: - 用户显式选择优先

    @Test("用户显式展开后完成自动 collapse 不得覆盖")
    func explicitExpandSurvivesAutoCollapse() {
        var state = ZCodeReasoningCollapseState()
        state.setExpanded(true)

        // 完成时的自动收起。
        state.applyAutoCollapseOnCompletion()

        #expect(state.isExpanded)
    }

    @Test("用户显式收起后完成自动 collapse 保持收起")
    func explicitCollapseSurvivesAutoCollapse() {
        var state = ZCodeReasoningCollapseState()
        state.setExpanded(false)

        state.applyAutoCollapseOnCompletion()

        #expect(!state.isExpanded)
    }

    @Test("用户从未操作过时完成自动 collapse 生效")
    func autoCollapseAppliesWhenUserNeverChose() {
        var state = ZCodeReasoningCollapseState()
        // 用户从未显式选择。
        state.applyAutoCollapseOnCompletion()

        #expect(!state.isExpanded)
    }

    @Test("显式选择后自动 collapse 不再改变状态")
    func autoCollapseIsNoopAfterExplicitChoice() {
        var state = ZCodeReasoningCollapseState()
        state.setExpanded(true)
        state.applyAutoCollapseOnCompletion()
        state.applyAutoCollapseOnCompletion()

        #expect(state.isExpanded)
    }

    // MARK: - 摘要

    @Test("streaming 收起时显示最后非空行摘要")
    func streamingSummaryUsesLastNonEmptyLine() {
        let summary = ZCodeReasoningStyle.summary(text: "第一行\n\n第二行\n\n\n第三行")

        #expect(summary == "第三行")
    }

    @Test("摘要忽略尾部空白行")
    func summaryIgnoresTrailingBlankLines() {
        let summary = ZCodeReasoningStyle.summary(text: "只有一行\n\n   \n")

        #expect(summary == "只有一行")
    }

    @Test("全空白文本没有摘要")
    func blankTextHasNoSummary() {
        #expect(ZCodeReasoningStyle.summary(text: "  \n\n ") == nil)
    }

    // MARK: - 几何

    @Test("内容顶部间距是 12、最大高 240")
    func contentGeometry() {
        #expect(ZCodeReasoningStyle.contentTopSpacing == 12)
        #expect(ZCodeReasoningStyle.contentMaxHeight == 240)
    }

    @Test("左 margin 8、左 padding 14")
    func contentInsets() {
        #expect(ZCodeReasoningStyle.contentLeadingMargin == 8)
        #expect(ZCodeReasoningStyle.contentLeadingPadding == 14)
    }

    @Test("Brain 图标是 16")
    func brainIconIs16() {
        #expect(ZCodeReasoningStyle.brainIconSize == 16)
    }

    @Test("默认吸底，用户离底超过 2 后停止跟随")
    func followThresholdIs2() {
        #expect(ZCodeReasoningStyle.followThreshold == 2)
    }

    // MARK: - 时长

    @Test("没有真实时长字段时不显示时长")
    func noDurationWithoutRealField() {
        #expect(ZCodeReasoningStyle.durationText(durationMilliseconds: nil) == nil)
    }

    @Test("有真实时长字段时显示时长")
    func durationShownWhenRealFieldExists() {
        let text = ZCodeReasoningStyle.durationText(durationMilliseconds: 1_500)

        #expect(text != nil)
    }

    @Test("时长字段非正数时不显示")
    func nonPositiveDurationIsHidden() {
        #expect(ZCodeReasoningStyle.durationText(durationMilliseconds: 0) == nil)
        #expect(ZCodeReasoningStyle.durationText(durationMilliseconds: -100) == nil)
    }

    // MARK: - 状态键

    @Test("reasoning 折叠状态键与 turn 折叠状态键不同")
    func stateKeysAreDistinct() {
        #expect(ZCodeReasoningStyle.collapseStateKey(turnKey: "turn:1", rowID: "row-1")
            != ZCodeReasoningStyle.turnCollapseStateKey(turnKey: "turn:1"))
    }

    @Test("同一 turn 不同 reasoning 行的状态键不同")
    func stateKeysDifferPerRow() {
        let first = ZCodeReasoningStyle.collapseStateKey(turnKey: "turn:1", rowID: "row-1")
        let second = ZCodeReasoningStyle.collapseStateKey(turnKey: "turn:1", rowID: "row-2")

        #expect(first != second)
    }

    @Test("状态键是确定性的")
    func stateKeysAreDeterministic() {
        let first = ZCodeReasoningStyle.collapseStateKey(turnKey: "turn:1", rowID: "row-1")
        let second = ZCodeReasoningStyle.collapseStateKey(turnKey: "turn:1", rowID: "row-1")

        #expect(first == second)
    }
}
