import CoreGraphics
import Testing
@testable import PluginMessageListBrief

struct MessageListSendPositioningTests {
    @Test("发送后尾部留白把最新回合定位在上方四分之一")
    func reservesViewportBelowShortTurn() {
        #expect(
            MessageListSendPositioning.tailReserve(
                viewportHeight: 800,
                activeTurnHeight: 100
            ) == 500
        )
    }

    @Test("回合高度超过目标区域时不添加负留白")
    func clampsReserveToZero() {
        #expect(
            MessageListSendPositioning.tailReserve(
                viewportHeight: 800,
                activeTurnHeight: 700
            ) == 0
        )
    }

    @Test("流式回合使用与内容高度无关的稳定尾部留白")
    func conservativeReserveIsStable() {
        #expect(
            MessageListSendPositioning.conservativeTailReserve(viewportHeight: 800) == 600
        )
        #expect(
            MessageListSendPositioning.conservativeTailReserve(viewportHeight: .nan) == 0
        )
    }
}
