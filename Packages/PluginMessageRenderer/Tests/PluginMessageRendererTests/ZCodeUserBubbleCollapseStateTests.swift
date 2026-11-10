import Foundation
import Testing
@testable import PluginMessageRenderer

/// V4（ZCode）用户气泡长文折叠状态机契约测试。
///
/// - Important: UI 测试只能观察「AX 上的 label 变了」，
///   真正的状态机语义（展开 / 收起 / 身份变化重置）必须由单元测试守住。
@Suite("ZCode 用户气泡折叠状态")
struct ZCodeUserBubbleCollapseStateTests {

    @Test("默认收起")
    func defaultCollapsed() {
        let state = ZCodeUserBubbleCollapseState()
        #expect(state.isExpanded == false)
    }

    @Test("显式展开后是展开")
    func explicitExpand() {
        var state = ZCodeUserBubbleCollapseState()
        state.setExpanded(true)

        #expect(state.isExpanded)
    }

    @Test("显式收起后是收起")
    func explicitCollapse() {
        var state = ZCodeUserBubbleCollapseState()
        state.setExpanded(true)
        state.setExpanded(false)

        #expect(state.isExpanded == false)
    }

    @Test("首次观察只记录身份，不改变展开状态")
    func firstObservationDoesNotReset() {
        var state = ZCodeUserBubbleCollapseState()
        state.setExpanded(true)

        // 首次挂载：只记录身份。
        state.updateIdentity(content: "内容", rowID: "row-1")

        #expect(state.isExpanded, "首次观察把用户的展开状态清掉了")
    }

    @Test("身份变化后重置为收起")
    func identityChangeResets() {
        var state = ZCodeUserBubbleCollapseState()
        state.updateIdentity(content: "内容", rowID: "row-1")
        state.setExpanded(true)

        // 换了一条消息（同一行 id，内容变了）。
        state.updateIdentity(content: "新内容", rowID: "row-1")

        #expect(state.isExpanded == false)
    }

    @Test("行 id 变化后重置为收起")
    func rowIDChangeResets() {
        var state = ZCodeUserBubbleCollapseState()
        state.updateIdentity(content: "内容", rowID: "row-1")
        state.setExpanded(true)

        state.updateIdentity(content: "内容", rowID: "row-2")

        #expect(state.isExpanded == false)
    }

    @Test("展开与收起的文案不同，供辅助功能朗读")
    func expandedAndCollapsedLabelsDiffer() {
        // - Note: SwiftUI 的 Button 会把 label 当作 AX 的 `value` 暴露，
        //   `accessibilityValue` 不会单独呈现。
        //   因此「展开 / 收起」必须由 label 承载，
        //   两者的文案必须不同，否则 UI 测试与辅助功能都读不出状态。
        let collapsedLabel = ZCodeUserBubbleStyle.toggleLabel(isExpanded: false)
        let expandedLabel = ZCodeUserBubbleStyle.toggleLabel(isExpanded: true)

        #expect(!collapsedLabel.isEmpty)
        #expect(!expandedLabel.isEmpty)
        #expect(collapsedLabel != expandedLabel)
    }

    @Test("身份不变时保持展开")
    func sameIdentityKeepsExpanded() {
        var state = ZCodeUserBubbleCollapseState()
        state.updateIdentity(content: "内容", rowID: "row-1")
        state.setExpanded(true)

        // 同样的身份再观察一次（视图重绘）。
        state.updateIdentity(content: "内容", rowID: "row-1")

        #expect(state.isExpanded, "视图重绘把用户的展开状态清掉了")
    }
}
