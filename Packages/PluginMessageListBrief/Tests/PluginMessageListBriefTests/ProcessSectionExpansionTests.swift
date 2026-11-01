import Foundation
import Testing
@testable import PluginMessageListBrief

/// 过程折叠区的**自动展开**行为。
///
/// 自动展开要满足两个互相拉扯的要求：
///
/// 1. 用户发送消息后，过程区**自动展开**（用户不用点按钮）；
/// 2. 用户手动折叠后，**不得**被自动展开覆盖 —— 否则就成了「强制展开」。
@MainActor
struct ProcessSectionExpansionTests {
    // MARK: - 初始状态

    @Test("活跃回合默认展开：用户发送消息后不用点按钮就能看到过程")
    func activeTurnExpandsByDefault() {
        let expansion = ProcessSectionExpansion(isActive: true)
        #expect(expansion.isExpanded, "活跃回合应默认展开")
    }

    @Test("历史回合默认折叠：长会话不会被几十个过程区刷屏")
    func historicalTurnCollapsesByDefault() {
        let expansion = ProcessSectionExpansion(isActive: false)
        #expect(!expansion.isExpanded, "历史回合应默认折叠")
    }

    // MARK: - 用户意图优先

    @Test("用户手动折叠后，自动展开不覆盖用户的选择")
    func userCollapseIsNotOverridden() {
        var expansion = ProcessSectionExpansion(isActive: true)
        #expect(expansion.isExpanded)

        // 用户手动折叠。
        expansion.userToggled(toExpanded: false)
        #expect(!expansion.isExpanded)

        // 新的活跃回合到来 —— 不应重新展开。
        expansion.turnStateChanged(isActive: true)
        #expect(
            !expansion.isExpanded,
            "用户已手动折叠，自动展开不得覆盖用户意图"
        )
    }

    @Test("用户手动展开后保持展开")
    func userExpandSticks() {
        var expansion = ProcessSectionExpansion(isActive: false)
        #expect(!expansion.isExpanded)

        expansion.userToggled(toExpanded: true)
        #expect(expansion.isExpanded)

        expansion.turnStateChanged(isActive: true)
        #expect(expansion.isExpanded, "用户手动展开应被尊重")
    }

    @Test("回合结束后保持用户最后看到的状态")
    func turnEndKeepsCurrentState() {
        var expansion = ProcessSectionExpansion(isActive: true)
        #expect(expansion.isExpanded)

        // 回合结束 —— 保持展开（用户正在看过程区）。
        expansion.turnStateChanged(isActive: false)
        #expect(expansion.isExpanded, "回合结束不应改变展开状态")
    }

    @Test("用户手动折叠后，回合结束仍保持折叠")
    func userCollapseSurvivesTurnEnd() {
        var expansion = ProcessSectionExpansion(isActive: true)
        expansion.userToggled(toExpanded: false)

        expansion.turnStateChanged(isActive: false)
        #expect(!expansion.isExpanded, "用户的手动折叠应跨回合保留")
    }

    // MARK: - 状态机语义

    @Test("自动展开态不等于用户展开态：前者可被自动逻辑覆盖")
    func automaticStateIsDistinctFromUserState() {
        let automatic = ProcessSectionExpansionState.expandedAutomatically
        let byUser = ProcessSectionExpansionState.expandedByUser
        #expect(automatic != byUser, "两种展开态必须可区分")
        #expect(automatic.isExpanded)
        #expect(byUser.isExpanded)
    }

    @Test("折叠态不展开")
    func collapsedIsNotExpanded() {
        #expect(!ProcessSectionExpansionState.collapsed.isExpanded)
    }

    @Test("用户切换状态：展开↔折叠双向")
    func userToggleSwitchesBothWays() {
        var state = ProcessSectionExpansionState.collapsed
        state.userToggled(toExpanded: true)
        #expect(state == .expandedByUser)

        state.userToggled(toExpanded: false)
        #expect(state == .collapsed)
    }
}
