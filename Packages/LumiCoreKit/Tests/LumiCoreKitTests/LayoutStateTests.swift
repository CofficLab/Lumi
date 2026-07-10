import Combine
import CoreGraphics
import Foundation
import Testing
@testable import LumiCoreKit

@Suite(.serialized) struct LayoutStateTests {

    // MARK: - 尺寸读写与默认值回退

    @MainActor
    @Test func railWidthFallsBackToDefaultWhenUnset() {
        let state = LumiLayoutState()
        #expect(state.railWidth(for: "LumiEditor") == 240)
        #expect(state.storedRailWidth(for: "LumiEditor") == nil)
    }

    @MainActor
    @Test func railWidthReturnsCustomFallbackWhenUnset() {
        let state = LumiLayoutState()
        #expect(state.railWidth(for: "LumiEditor", fallback: 300) == 300)
    }

    @MainActor
    @Test func setRailWidthStoresAndReadsBack() {
        let state = LumiLayoutState()
        state.setRailWidth(312, for: "LumiEditor")
        #expect(state.railWidth(for: "LumiEditor") == 312)
        #expect(state.storedRailWidth(for: "LumiEditor") == 312)
    }

    @MainActor
    @Test func bottomPanelHeightStoresAndReadsBack() {
        let state = LumiLayoutState()
        #expect(state.bottomPanelHeight(for: "main") == 200)
        state.setBottomPanelHeight(450, for: "main")
        #expect(state.bottomPanelHeight(for: "main") == 450)
        #expect(state.storedBottomPanelHeight(for: "main") == 450)
    }

    @MainActor
    @Test func chatSectionWidthStoresAndReadsBack() {
        let state = LumiLayoutState()
        #expect(state.chatSectionWidth(for: "main", layout: .wide) == 320)
        state.setChatSectionWidth(500, for: "main", layout: .wide)
        #expect(state.chatSectionWidth(for: "main", layout: .wide) == 500)
        #expect(state.storedChatSectionWidth(for: "main", layout: .wide) == 500)
    }

    @MainActor
    @Test func chatSectionWidthIsolatesByLayoutSuffix() {
        let state = LumiLayoutState()
        state.setChatSectionWidth(500, for: "main", layout: .wide)
        // narrow 档位应独立、未受 wide 设置影响
        #expect(state.storedChatSectionWidth(for: "main", layout: .narrow) == nil)
        #expect(state.chatSectionWidth(for: "main", layout: .narrow) == 320)
    }

    @MainActor
    @Test func dimensionsIsolateByViewContainerID() {
        let state = LumiLayoutState()
        state.setRailWidth(200, for: "LumiEditor")
        state.setRailWidth(400, for: "LumiAgent")
        #expect(state.railWidth(for: "LumiEditor") == 200)
        #expect(state.railWidth(for: "LumiAgent") == 400)
    }

    // MARK: - 通知发送

    @MainActor
    @Test func setRailWidthPostsNotification() async {
        let state = LumiLayoutState()
        let box = EventBox<String, CGFloat>()

        let token = NotificationCenter.default.addObserver(
            forName: .railWidthDidChange,
            object: nil,
            queue: .main
        ) { notification in
            guard let id = notification.userInfo?["containerID"] as? String,
                  let width = notification.userInfo?["width"] as? CGFloat
            else { return }
            box.record(id, width)
        }
        defer { NotificationCenter.default.removeObserver(token) }

        state.setRailWidth(333, for: "LumiEditor")

        // NotificationCenter 主队列投递是异步的，等待一次 runloop。
        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)

        let received = box.values
        #expect(received.count == 1)
        #expect(received[0].0 == "LumiEditor")
        #expect(received[0].1 == 333)
    }

    @MainActor
    @Test func setRailWidthDoesNotNotifyForSameValue() async {
        let state = LumiLayoutState()
        state.setRailWidth(300, for: "main")

        let counter = CounterBox()
        let token = NotificationCenter.default.addObserver(
            forName: .railWidthDidChange,
            object: nil,
            queue: .main
        ) { _ in counter.increment() }
        defer { NotificationCenter.default.removeObserver(token) }

        state.setRailWidth(300, for: "main") // 同值，不应发通知

        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(counter.count == 0)
    }

    @MainActor
    @Test func setBottomPanelHeightPostsNotification() async {
        let state = LumiLayoutState()
        let box = EventBox<String, CGFloat>()

        let token = NotificationCenter.default.addObserver(
            forName: .bottomPanelHeightDidChange,
            object: nil,
            queue: .main
        ) { notification in
            guard let id = notification.userInfo?["containerID"] as? String,
                  let height = notification.userInfo?["height"] as? CGFloat
            else { return }
            box.record(id, height)
        }
        defer { NotificationCenter.default.removeObserver(token) }

        state.setBottomPanelHeight(278, for: "main")

        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)
        let received = box.values
        #expect(received.count == 1)
        #expect(received[0].0 == "main")
        #expect(received[0].1 == 278)
    }

    @MainActor
    @Test func setChatSectionWidthPostsNotificationWithLayoutSuffix() async {
        let state = LumiLayoutState()
        let box = EventBox<String, CGFloat>()
        var layoutSuffix: String?

        let token = NotificationCenter.default.addObserver(
            forName: .chatSectionWidthDidChange,
            object: nil,
            queue: .main
        ) { notification in
            guard let id = notification.userInfo?["containerID"] as? String,
                  let layout = notification.userInfo?["layout"] as? String,
                  let width = notification.userInfo?["width"] as? CGFloat
            else { return }
            box.record(id, width)
            layoutSuffix = layout
        }
        defer { NotificationCenter.default.removeObserver(token) }

        state.setChatSectionWidth(420, for: "LumiEditor", layout: .narrow)

        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)
        let received = box.values
        #expect(received.count == 1)
        #expect(received[0].0 == "LumiEditor")
        #expect(layoutSuffix == "narrow")
        #expect(received[0].1 == 420)
    }

    // MARK: - restore 路径不发通知

    @MainActor
    @Test func restoreRailWidthDoesNotPostNotification() async {
        let state = LumiLayoutState()
        let counter = CounterBox()
        let token = NotificationCenter.default.addObserver(
            forName: .railWidthDidChange,
            object: nil,
            queue: .main
        ) { _ in counter.increment() }
        defer { NotificationCenter.default.removeObserver(token) }

        state.restoreRailWidth(300, for: "main")
        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)

        #expect(counter.count == 0)
        #expect(state.railWidth(for: "main") == 300)
    }

    // MARK: - 自定义默认值

    @MainActor
    @Test func customDefaultsApplyWhenUnset() {
        let state = LumiLayoutState(
            defaultRailWidth: 260,
            defaultChatSectionWidth: 360,
            defaultBottomPanelHeight: 220
        )
        #expect(state.railWidth(for: "main") == 260)
        #expect(state.chatSectionWidth(for: "main", layout: .wide) == 360)
        #expect(state.bottomPanelHeight(for: "main") == 220)
    }
}

/// 线程安全的事件收集器，供测试在主队列回调中按顺序记录通知负载。
private final class EventBox<A, B>: @unchecked Sendable {
    private var items: [(A, B)] = []
    private let lock = NSLock()

    func record(_ a: A, _ b: B) {
        lock.lock(); items.append((a, b)); lock.unlock()
    }

    var values: [(A, B)] {
        lock.lock(); defer { lock.unlock() }
        return items
    }
}

/// 线程安全的计数器。
private final class CounterBox: @unchecked Sendable {
    private var _count = 0
    private let lock = NSLock()

    var count: Int { lock.lock(); defer { lock.unlock() }; return _count }

    func increment() { lock.lock(); _count += 1; lock.unlock() }
}
