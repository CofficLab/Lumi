import Combine
import CoreGraphics
import Foundation
import Testing
@testable import LumiCoreKit

@Suite(.serialized) struct LayoutStateTests {

    // MARK: - divider 位置读写与默认值回退

    @MainActor
    @Test func railDividerFallsBackToDefaultWhenUnset() {
        let state = LayoutState()
        #expect(state.railDivider(for: "LumiEditor") == 240)
        #expect(state.storedRailDivider(for: "LumiEditor") == nil)
    }

    @MainActor
    @Test func railDividerReturnsCustomFallbackWhenUnset() {
        let state = LayoutState()
        #expect(state.railDivider(for: "LumiEditor", fallback: 300) == 300)
    }

    @MainActor
    @Test func setRailDividerStoresAndReadsBack() {
        let state = LayoutState()
        state.setRailDivider(312, for: "LumiEditor")
        #expect(state.railDivider(for: "LumiEditor") == 312)
        #expect(state.storedRailDivider(for: "LumiEditor") == 312)
    }

    @MainActor
    @Test func bottomPanelDividerStoresAndReadsBack() {
        let state = LayoutState()
        #expect(state.bottomPanelDivider(for: "main") == 400)
        state.setBottomPanelDivider(450, for: "main")
        #expect(state.bottomPanelDivider(for: "main") == 450)
        #expect(state.storedBottomPanelDivider(for: "main") == 450)
    }

    @MainActor
    @Test func chatSectionDividerStoresAndReadsBack() {
        let state = LayoutState()
        #expect(state.chatSectionDivider(for: "main", layout: .wide) == 320)
        state.setChatSectionDivider(500, for: "main", layout: .wide)
        #expect(state.chatSectionDivider(for: "main", layout: .wide) == 500)
        #expect(state.storedChatSectionDivider(for: "main", layout: .wide) == 500)
    }

    @MainActor
    @Test func chatSectionDividerIsolatesByLayoutSuffix() {
        let state = LayoutState()
        state.setChatSectionDivider(500, for: "main", layout: .wide)
        // narrow 档位应独立、未受 wide 设置影响
        #expect(state.storedChatSectionDivider(for: "main", layout: .narrow) == nil)
        #expect(state.chatSectionDivider(for: "main", layout: .narrow) == 320)
    }

    @MainActor
    @Test func dividersIsolateByViewContainerID() {
        let state = LayoutState()
        state.setRailDivider(200, for: "LumiEditor")
        state.setRailDivider(400, for: "LumiAgent")
        #expect(state.railDivider(for: "LumiEditor") == 200)
        #expect(state.railDivider(for: "LumiAgent") == 400)
    }

    // MARK: - 通知发送

    @MainActor
    @Test func setRailDividerPostsNotification() async {
        let state = LayoutState()
        let box = EventBox<String, CGFloat>()

        let token = NotificationCenter.default.addObserver(
            forName: .railDividerDidChange,
            object: nil,
            queue: .main
        ) { notification in
            guard let id = notification.userInfo?["containerID"] as? String,
                  let position = notification.userInfo?["position"] as? CGFloat
            else { return }
            box.record(id, position)
        }
        defer { NotificationCenter.default.removeObserver(token) }

        state.setRailDivider(333, for: "LumiEditor")

        // NotificationCenter 主队列投递是异步的，等待一次 runloop。
        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)

        let received = box.values
        #expect(received.count == 1)
        #expect(received[0].0 == "LumiEditor")
        #expect(received[0].1 == 333)
    }

    @MainActor
    @Test func setRailDividerDoesNotNotifyForSameValue() async {
        let state = LayoutState()
        state.setRailDivider(300, for: "main")

        let counter = CounterBox()
        let token = NotificationCenter.default.addObserver(
            forName: .railDividerDidChange,
            object: nil,
            queue: .main
        ) { _ in counter.increment() }
        defer { NotificationCenter.default.removeObserver(token) }

        state.setRailDivider(300, for: "main") // 同值，不应发通知

        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(counter.count == 0)
    }

    @MainActor
    @Test func setBottomPanelDividerPostsNotification() async {
        let state = LayoutState()
        let box = EventBox<String, CGFloat>()

        let token = NotificationCenter.default.addObserver(
            forName: .bottomPanelDividerDidChange,
            object: nil,
            queue: .main
        ) { notification in
            guard let id = notification.userInfo?["containerID"] as? String,
                  let position = notification.userInfo?["position"] as? CGFloat
            else { return }
            box.record(id, position)
        }
        defer { NotificationCenter.default.removeObserver(token) }

        state.setBottomPanelDivider(278, for: "main")

        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)
        let received = box.values
        #expect(received.count == 1)
        #expect(received[0].0 == "main")
        #expect(received[0].1 == 278)
    }

    @MainActor
    @Test func setChatSectionDividerPostsNotificationWithLayoutSuffix() async {
        let state = LayoutState()
        let box = EventBox<String, CGFloat>()
        var layoutSuffix: String?

        let token = NotificationCenter.default.addObserver(
            forName: .chatSectionDividerDidChange,
            object: nil,
            queue: .main
        ) { notification in
            guard let id = notification.userInfo?["containerID"] as? String,
                  let layout = notification.userInfo?["layout"] as? String,
                  let position = notification.userInfo?["position"] as? CGFloat
            else { return }
            box.record(id, position)
            layoutSuffix = layout
        }
        defer { NotificationCenter.default.removeObserver(token) }

        state.setChatSectionDivider(420, for: "LumiEditor", layout: .narrow)

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
    @Test func restoreRailDividerDoesNotPostNotification() async {
        let state = LayoutState()
        let counter = CounterBox()
        let token = NotificationCenter.default.addObserver(
            forName: .railDividerDidChange,
            object: nil,
            queue: .main
        ) { _ in counter.increment() }
        defer { NotificationCenter.default.removeObserver(token) }

        state.restoreRailDivider(300, for: "main")
        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)

        #expect(counter.count == 0)
        #expect(state.railDivider(for: "main") == 300)
    }

    // MARK: - 自定义默认值

    @MainActor
    @Test func customDefaultsApplyWhenUnset() {
        let state = LayoutState(
            defaultRailDivider: 260,
            defaultChatSectionDivider: 360,
            defaultBottomPanelDivider: 420
        )
        #expect(state.railDivider(for: "main") == 260)
        #expect(state.chatSectionDivider(for: "main", layout: .wide) == 360)
        #expect(state.bottomPanelDivider(for: "main") == 420)
    }

    // MARK: - Panel column 宽度（仅供"三栏宽度"日志使用）

    @MainActor
    @Test func setPanelColumnWidthStoresAndReadsBack() {
        let state = LayoutState()
        #expect(state.panelColumnWidth(for: "LumiEditor") == nil)
        state.setPanelColumnWidth(800, for: "LumiEditor")
        #expect(state.panelColumnWidth(for: "LumiEditor") == 800)
    }

    @MainActor
    @Test func setPanelColumnWidthIgnoresNonPositiveValues() {
        let state = LayoutState()
        state.setPanelColumnWidth(800, for: "LumiEditor")
        state.setPanelColumnWidth(0, for: "LumiEditor")
        state.setPanelColumnWidth(-10, for: "LumiEditor")
        // 0 和负值不应覆盖已有有效值
        #expect(state.panelColumnWidth(for: "LumiEditor") == 800)
    }

    @MainActor
    @Test func setPanelColumnWidthIsolatesByViewContainerID() {
        let state = LayoutState()
        state.setPanelColumnWidth(800, for: "LumiEditor")
        state.setPanelColumnWidth(1200, for: "LumiAgent")
        #expect(state.panelColumnWidth(for: "LumiEditor") == 800)
        #expect(state.panelColumnWidth(for: "LumiAgent") == 1200)
        #expect(state.panelColumnWidth(for: "missing") == nil)
    }

    @MainActor
    @Test func setRailDividerCanDeriveMiddleFromPanelColumnWidth() {
        let state = LayoutState()
        // 模拟视图层同步 panel column 宽度
        state.setPanelColumnWidth(800, for: "LumiEditor")
        state.setRailDivider(240, for: "LumiEditor")
        // 推算 middle = panelColumn - rail = 800 - 240 = 560
        #expect(state.railDivider(for: "LumiEditor") == 240)
        #expect((state.panelColumnWidth(for: "LumiEditor") ?? 0) - state.railDivider(for: "LumiEditor") == 560)
    }

    @MainActor
    @Test func setPanelColumnWidthDoesNotPostNotification() async {
        let state = LayoutState()
        let counter = CounterBox()
        // 监听所有 divider 通知，确保 setPanelColumnWidth 不会发出任何通知
        let tokens: [NSObjectProtocol] = [
            .railDividerDidChange,
            .chatSectionDividerDidChange,
            .bottomPanelDividerDidChange
        ].map { name in
            NotificationCenter.default.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { _ in counter.increment() }
        }
        defer { tokens.forEach { NotificationCenter.default.removeObserver($0) } }

        state.setPanelColumnWidth(800, for: "LumiEditor")
        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(counter.count == 0)
    }

    // MARK: - restore 路径不发通知（补 chatSection / bottomPanel 的对照）

    @MainActor
    @Test func restoreChatSectionDividerDoesNotPostNotification() async {
        let state = LayoutState()
        let counter = CounterBox()
        let token = NotificationCenter.default.addObserver(
            forName: .chatSectionDividerDidChange,
            object: nil,
            queue: .main
        ) { _ in counter.increment() }
        defer { NotificationCenter.default.removeObserver(token) }

        state.restoreChatSectionDivider(480, for: "main", layout: .wide)
        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)

        #expect(counter.count == 0)
        #expect(state.chatSectionDivider(for: "main", layout: .wide) == 480)
    }

    @MainActor
    @Test func restoreBottomPanelDividerDoesNotPostNotification() async {
        let state = LayoutState()
        let counter = CounterBox()
        let token = NotificationCenter.default.addObserver(
            forName: .bottomPanelDividerDidChange,
            object: nil,
            queue: .main
        ) { _ in counter.increment() }
        defer { NotificationCenter.default.removeObserver(token) }

        state.restoreBottomPanelDivider(450, for: "main")
        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)

        #expect(counter.count == 0)
        #expect(state.bottomPanelDivider(for: "main") == 450)
    }

    // MARK: - 同值不通知（补 chatSection / bottomPanel 的对照）

    @MainActor
    @Test func setChatSectionDividerDoesNotNotifyForSameValue() async {
        let state = LayoutState()
        state.setChatSectionDivider(500, for: "main", layout: .wide)
        let counter = CounterBox()
        let token = NotificationCenter.default.addObserver(
            forName: .chatSectionDividerDidChange,
            object: nil,
            queue: .main
        ) { _ in counter.increment() }
        defer { NotificationCenter.default.removeObserver(token) }

        // 再设同样的值 → 不应发通知。
        state.setChatSectionDivider(500, for: "main", layout: .wide)
        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)

        #expect(counter.count == 0)
    }

    @MainActor
    @Test func setBottomPanelDividerDoesNotNotifyForSameValue() async {
        let state = LayoutState()
        state.setBottomPanelDivider(450, for: "main")
        let counter = CounterBox()
        let token = NotificationCenter.default.addObserver(
            forName: .bottomPanelDividerDidChange,
            object: nil,
            queue: .main
        ) { _ in counter.increment() }
        defer { NotificationCenter.default.removeObserver(token) }

        state.setBottomPanelDivider(450, for: "main")
        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)

        #expect(counter.count == 0)
    }

    // MARK: - LayoutEventPayload.cgFloat 解码

    @Test func cgFloatDecodesFromCGFloat() {
        #expect(LayoutEventPayload.cgFloat(from: CGFloat(3.14) as Any?) == 3.14)
    }

    @Test func cgFloatDecodesFromNSNumber() {
        #expect(LayoutEventPayload.cgFloat(from: NSNumber(value: 42.5) as Any?) == 42.5)
    }

    @Test func cgFloatDecodesFromDouble() {
        #expect(LayoutEventPayload.cgFloat(from: Double(7.0) as Any?) == 7.0)
    }

    @Test func cgFloatReturnsNilForInvalidInput() {
        #expect(LayoutEventPayload.cgFloat(from: nil) == nil)
        #expect(LayoutEventPayload.cgFloat(from: "not a number" as Any?) == nil)
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
