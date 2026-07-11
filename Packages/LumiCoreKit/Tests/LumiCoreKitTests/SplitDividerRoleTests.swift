import CoreGraphics
import Testing
@testable import LumiCoreKit

@Suite struct SplitDividerRoleTests {

    // MARK: - Equatable

    @Test func equalRailRolesAreEqual() {
        #expect(SplitDividerRole.rail(viewContainerID: "a") == .rail(viewContainerID: "a"))
    }

    @Test func railRolesWithDifferentIDsAreNotEqual() {
        #expect(SplitDividerRole.rail(viewContainerID: "a") != .rail(viewContainerID: "b"))
    }

    @Test func equalChatSectionRolesAreEqual() {
        #expect(
            SplitDividerRole.chatSection(viewContainerID: "a", layout: .narrow)
            == .chatSection(viewContainerID: "a", layout: .narrow)
        )
    }

    @Test func chatSectionRolesDifferByLayoutAreNotEqual() {
        // 同 id 但不同 layout 档位应判不等——这是跨容器切换恢复的关键。
        #expect(
            SplitDividerRole.chatSection(viewContainerID: "a", layout: .narrow)
            != .chatSection(viewContainerID: "a", layout: .wide)
        )
    }

    @Test func chatSectionRolesDifferByIDAreNotEqual() {
        #expect(
            SplitDividerRole.chatSection(viewContainerID: "a", layout: .narrow)
            != .chatSection(viewContainerID: "b", layout: .narrow)
        )
    }

    @Test func differentCasesAreNotEqual() {
        // 跨 case 必须不等，否则 updateConfiguration 的 roleChanged 检测会失效。
        #expect(SplitDividerRole.rail(viewContainerID: "a") != .bottomPanel(viewContainerID: "a"))
        #expect(SplitDividerRole.rail(viewContainerID: "a") != .chatSection(viewContainerID: "a", layout: .narrow))
        #expect(SplitDividerRole.bottomPanel(viewContainerID: "a") != .chatSection(viewContainerID: "a", layout: .narrow))
    }

    // MARK: - viewContainerID

    @Test func viewContainerIDExtractsFromEachCase() {
        #expect(SplitDividerRole.rail(viewContainerID: "LumiEditor").viewContainerID == "LumiEditor")
        #expect(SplitDividerRole.bottomPanel(viewContainerID: "LumiAgent").viewContainerID == "LumiAgent")
        #expect(SplitDividerRole.chatSection(viewContainerID: "main", layout: .wide).viewContainerID == "main")
    }

    // MARK: - defaultPosition

    @Test func defaultPositionReturnsBuiltinDefaults() {
        #expect(SplitDividerRole.rail(viewContainerID: "a").defaultPosition() == 240)
        #expect(SplitDividerRole.bottomPanel(viewContainerID: "a").defaultPosition() == 400)
        // chatSection 的默认位置随布局档位的 idealWidth 变化。
        #expect(SplitDividerRole.chatSection(viewContainerID: "a", layout: .narrow).defaultPosition() == 320)
        #expect(SplitDividerRole.chatSection(viewContainerID: "a", layout: .wide).defaultPosition() == 480)
    }

    // MARK: - expectsVerticalSplit

    @Test func railAndChatSectionExpectVerticalSplit() {
        // HSplitView：左右分栏，分隔线垂直 → isVertical == true。
        #expect(SplitDividerRole.rail(viewContainerID: "a").expectsVerticalSplit() == true)
        #expect(SplitDividerRole.chatSection(viewContainerID: "a", layout: .wide).expectsVerticalSplit() == true)
    }

    @Test func bottomPanelDoesNotExpectVerticalSplit() {
        // VSplitView：上下分栏，分隔线水平 → isVertical == false。
        #expect(SplitDividerRole.bottomPanel(viewContainerID: "a").expectsVerticalSplit() == false)
    }

    // MARK: - participatesInHorizontalThreeColumns

    @Test func railAndChatSectionParticipateInThreeColumns() {
        #expect(SplitDividerRole.rail(viewContainerID: "a").participatesInHorizontalThreeColumns == true)
        #expect(SplitDividerRole.chatSection(viewContainerID: "a", layout: .wide).participatesInHorizontalThreeColumns == true)
    }

    @Test func bottomPanelDoesNotParticipateInThreeColumns() {
        #expect(SplitDividerRole.bottomPanel(viewContainerID: "a").participatesInHorizontalThreeColumns == false)
    }

    // MARK: - prefersLargestCandidate

    @Test func chatSectionPrefersLargestCandidate() {
        // chatSection 挂在最外层（Panel | Chat）→ 候选选面积最大的。
        #expect(SplitDividerRole.chatSection(viewContainerID: "a", layout: .wide).prefersLargestCandidate == true)
    }

    @Test func railAndBottomPanelPreferSmallestCandidate() {
        // rail / bottomPanel 挂在内层 → 候选选面积最小的。
        #expect(SplitDividerRole.rail(viewContainerID: "a").prefersLargestCandidate == false)
        #expect(SplitDividerRole.bottomPanel(viewContainerID: "a").prefersLargestCandidate == false)
    }
}
