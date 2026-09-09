import CoreGraphics
import Testing
@testable import PluginMessageListBrief

struct MessageListSendPositioningTests {
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
