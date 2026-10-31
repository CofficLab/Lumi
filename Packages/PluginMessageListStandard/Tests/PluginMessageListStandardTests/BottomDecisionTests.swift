import CoreGraphics
import Foundation
import Testing
@testable import PluginMessageListStandard

/// 这些断言直接调用生产代码里的 `BottomDecision`（与
/// `ScrollViewBottomTracker.reevaluate()` 共用同一实现），不存在副本漂移。
@MainActor
private func evaluate(
    documentHeight: CGFloat,
    visibleHeight: CGFloat = 600,
    offsetY: CGFloat,
    lastAtBottom: Bool
) -> Bool? {
    BottomDecision.evaluate(
        documentHeight: documentHeight,
        visibleHeight: visibleHeight,
        offsetY: offsetY,
        lastAtBottom: lastAtBottom,
        enterTolerance: MessageListScrollCoordinator.bottomEnterTolerance,
        leaveTolerance: MessageListScrollCoordinator.bottomLeaveTolerance
    )
}

@MainActor
@Test("底部判定：offset 落在底边时为真")
func bottomDecisionTrueAtExactBottom() {
    #expect(evaluate(documentHeight: 1_000, offsetY: 400, lastAtBottom: true) == true)
}

@MainActor
@Test("底部判定：远离底部时为假")
func bottomDecisionFalseFarFromBottom() {
    #expect(evaluate(documentHeight: 2_000, offsetY: 0, lastAtBottom: false) == false)
}

@MainActor
@Test("底部判定迟滞：留在底部时容忍更大距离，离开底部时要求更接近")
func bottomDecisionUsesHysteresisBand() {
    // 距离 = 50，介于 enter(24) 与 leave(96) 之间 —— 典型迟滞带
    let distance: CGFloat = 50
    let documentHeight: CGFloat = 1_000
    let visibleHeight: CGFloat = 600
    let offsetY = documentHeight - visibleHeight - distance

    #expect(evaluate(documentHeight: documentHeight, visibleHeight: visibleHeight, offsetY: offsetY, lastAtBottom: true) == true)
    #expect(evaluate(documentHeight: documentHeight, visibleHeight: visibleHeight, offsetY: offsetY, lastAtBottom: false) == false)
}

@MainActor
@Test("底部判定：文档远短于视口时视口顶部即底部")
func bottomDecisionShortDocumentIsAtBottom() {
    #expect(evaluate(documentHeight: 300, offsetY: 0, lastAtBottom: false) == true)
}

@MainActor
@Test("底部判定：距离恰在进入阈值边界上判为真")
func bottomDecisionEnterBoundaryIsInclusive() {
    let tolerance = MessageListScrollCoordinator.bottomEnterTolerance
    let documentHeight: CGFloat = 1_000
    let visibleHeight: CGFloat = 600
    let offsetY = documentHeight - visibleHeight - tolerance

    #expect(evaluate(documentHeight: documentHeight, visibleHeight: visibleHeight, offsetY: offsetY, lastAtBottom: false) == true)
}

@MainActor
@Test("底部判定：距离恰在离开阈值边界上判为真")
func bottomDecisionLeaveBoundaryIsInclusive() {
    let tolerance = MessageListScrollCoordinator.bottomLeaveTolerance
    let documentHeight: CGFloat = 1_000
    let visibleHeight: CGFloat = 600
    let offsetY = documentHeight - visibleHeight - tolerance

    #expect(evaluate(documentHeight: documentHeight, visibleHeight: visibleHeight, offsetY: offsetY, lastAtBottom: true) == true)
}

@MainActor
@Test("底部判定：视口高度为 0 或几何异常时放弃判定")
func bottomDecisionIgnoresInvalidGeometry() {
    #expect(evaluate(documentHeight: 1_000, visibleHeight: 0, offsetY: 0, lastAtBottom: true) == nil)
    #expect(evaluate(documentHeight: .nan, offsetY: 0, lastAtBottom: true) == nil)
    #expect(evaluate(documentHeight: 20_000_000, offsetY: 0, lastAtBottom: true) == nil)
}

@MainActor
@Test("底部判定：距离为负（内容短于视口且已滚过头）仍视为在底部")
func bottomDecisionHandlesNegativeDistance() {
    // document=600, visible=600, offset=100 → distance = -100
    #expect(evaluate(documentHeight: 600, visibleHeight: 600, offsetY: 100, lastAtBottom: false) == true)
}
