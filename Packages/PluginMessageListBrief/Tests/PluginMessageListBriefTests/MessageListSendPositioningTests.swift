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
}
