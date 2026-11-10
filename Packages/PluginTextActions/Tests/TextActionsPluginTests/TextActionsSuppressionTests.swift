import Foundation
import Testing
@testable import TextActionsPlugin

/// 回归覆盖 issue #1058：键盘消失后的抑制只覆盖那一次按键序列。
@Suite("TextSelectionSuppression")
struct TextSelectionSuppressionTests {

    private let copyKey: UInt16 = 8
    private let selectAllKey: UInt16 = 0

    @Test("匹配的同文本 keyUp 只被抑制一次")
    func matchingKeyUpIsSuppressedOnlyOnce() {
        var suppression = TextSelectionSuppression()
        suppression.suppress(text: "selected", keyCode: copyKey)

        let consumed = suppression.consumeMatch(text: "selected", keyCode: copyKey)
        #expect(consumed)
        #expect(!suppression.isActive)

        // 之后重新创建的相同选区必须重新显示菜单。
        let consumedAgain = suppression.consumeMatch(text: "selected", keyCode: copyKey)
        #expect(!consumedAgain)
    }

    @Test("键码不同视为新的选择动作并解除抑制")
    func differentKeyCodeStartsNewSelection() {
        var suppression = TextSelectionSuppression()
        suppression.suppress(text: "selected", keyCode: copyKey)

        suppression.clearIfKeyChanged(selectAllKey)

        #expect(!suppression.isActive)
        let consumed = suppression.consumeMatch(text: "selected", keyCode: selectAllKey)
        #expect(!consumed)
    }

    @Test("同一按键不会被 keyUp 清掉")
    func sameKeyCodeKeepsSuppression() {
        var suppression = TextSelectionSuppression()
        suppression.suppress(text: "selected", keyCode: copyKey)

        suppression.clearIfKeyChanged(copyKey)

        let consumed = suppression.consumeMatch(text: "selected", keyCode: copyKey)
        #expect(consumed)
    }

    @Test("选区清空后解除抑制")
    func clearingSelectionReleasesSuppression() {
        var suppression = TextSelectionSuppression()
        suppression.suppress(text: "selected", keyCode: copyKey)

        suppression.clear()

        #expect(!suppression.isActive)
        let consumed = suppression.consumeMatch(text: "selected", keyCode: copyKey)
        #expect(!consumed)
    }

    @Test("不同键码不命中抑制")
    func differentKeyCodeDoesNotMatch() {
        var suppression = TextSelectionSuppression()
        suppression.suppress(text: "selected", keyCode: copyKey)

        let consumed = suppression.consumeMatch(text: "selected", keyCode: selectAllKey)
        #expect(!consumed)
        #expect(suppression.isActive)
    }

    @Test("不同文本不命中抑制")
    func differentTextDoesNotMatch() {
        var suppression = TextSelectionSuppression()
        suppression.suppress(text: "selected", keyCode: copyKey)

        let consumed = suppression.consumeMatch(text: "another selection", keyCode: copyKey)
        #expect(!consumed)
    }

    @Test("没有展示中的文本时抑制不会生效")
    func missingPresentedTextDoesNotArm() {
        var suppression = TextSelectionSuppression()
        suppression.suppress(text: nil, keyCode: copyKey)

        #expect(!suppression.isActive)
        let consumed = suppression.consumeMatch(text: "selected", keyCode: copyKey)
        #expect(!consumed)
    }
}
