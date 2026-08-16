import Foundation
import Testing
@testable import KernelCore

@Suite("KernelCore Event Bus")
@MainActor
struct KernelCoreEventBusTests {
    private struct MessageEvent: KernelEvent, Equatable {
        let text: String
    }

    private struct OtherEvent: KernelEvent {
        let value: Int
    }

    @Test("订阅并收到同类型事件")
    func subscribeReceivesTypedEvent() {
        let bus = KernelCoreEventBus()
        var received: [MessageEvent] = []
        let sub = bus.subscribe(MessageEvent.self) { received.append($0) }

        bus.publish(MessageEvent(text: "hello"))
        bus.publish(MessageEvent(text: "world"))
        bus.publish(OtherEvent(value: 1))

        #expect(received == [MessageEvent(text: "hello"), MessageEvent(text: "world")])
        #expect(bus.activeSubscriptionCount == 1)
        sub.cancel()
        #expect(bus.activeSubscriptionCount == 0)
        #expect(sub.isCancelled)
    }

    @Test("取消后不再收到事件")
    func cancelledSubscriptionStops() {
        let bus = KernelCoreEventBus()
        var count = 0
        let sub = bus.subscribe(MessageEvent.self) { _ in count += 1 }

        bus.publish(MessageEvent(text: "a"))
        sub.cancel()
        bus.publish(MessageEvent(text: "b"))

        #expect(count == 1)
    }

    @Test("多个订阅者各自收到事件")
    func multipleSubscribers() {
        let bus = KernelCoreEventBus()
        var a = 0
        var b = 0
        let subA = bus.subscribe(MessageEvent.self) { _ in a += 1 }
        let subB = bus.subscribe(MessageEvent.self) { _ in b += 1 }

        bus.publish(MessageEvent(text: "x"))
        #expect(a == 1 && b == 1)
        subA.cancel()
        subB.cancel()
    }

    @Test("旧 Notification 桥转换为类型化事件")
    func legacyNotificationBridge() {
        let center = NotificationCenter()
        let bus = KernelCoreEventBus(notificationCenter: center)
        let legacyName = Notification.Name("com.test.legacy.message")
        var received: [MessageEvent] = []

        let bridge = bus.bridgeLegacyNotification(name: legacyName) { notification in
            guard let text = notification.userInfo?["text"] as? String else { return nil }
            return MessageEvent(text: text)
        }
        let sub = bus.subscribe(MessageEvent.self) { received.append($0) }

        center.post(name: legacyName, object: nil, userInfo: ["text": "from-legacy"])
        #expect(received == [MessageEvent(text: "from-legacy")])

        // 解析失败的通知被忽略
        center.post(name: legacyName, object: nil, userInfo: ["nope": 1])
        #expect(received.count == 1)

        // 取消桥接后不再接收
        bridge.cancel()
        center.post(name: legacyName, object: nil, userInfo: ["text": "after-cancel"])
        #expect(received.count == 1)
        sub.cancel()
    }

    @Test("publishAsLegacy 同时广播类型事件与旧通知")
    func publishAsLegacyBroadcastsBoth() {
        let center = NotificationCenter()
        let bus = KernelCoreEventBus(notificationCenter: center)
        let legacyName = Notification.Name("com.test.legacy.other")
        var typedCount = 0
        var legacyCount = 0

        let sub = bus.subscribe(OtherEvent.self) { _ in typedCount += 1 }
        let legacyObserver = center.addObserver(
            forName: legacyName, object: nil, queue: .main
        ) { _ in legacyCount += 1 }

        bus.publishAsLegacy(OtherEvent(value: 7), notificationName: legacyName, userInfo: ["v": 7])

        #expect(typedCount == 1)
        #expect(legacyCount == 1)
        sub.cancel()
        center.removeObserver(legacyObserver)
    }
}
