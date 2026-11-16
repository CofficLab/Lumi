import AppKit
import Foundation
import Testing
@testable import TextActionsPlugin

/// 回归「复制后弹菜单 / 普通单击弹菜单」：触发必须是「刚完成一次选择
/// 手势」，而不是「操作后恰好存在选区」。
///
/// 注入假事件监听与假选区读取，用合成 NSEvent 驱动真实的监听回调，
/// 断言是否触发了选区读取。读取替身恒返回 nil，因此不会构造真实浮层；
/// 「弹菜单」的必要条件是「发生读取」，守住读取即守住弹层。
@Suite("Text Actions 选区触发回归", .serialized)
@MainActor
struct TextActionsTriggerTests {

    // MARK: 单击 / 拖拽 / 连击

    @Test("普通单击不读取选区")
    func plainClickDoesNotReadSelection() async throws {
        let (manager, monitor, provider) = makeManager()
        defer { manager.stopMonitoring() }

        monitor.handler?(mouseEvent(.leftMouseDown))
        monitor.handler?(mouseEvent(.leftMouseUp))
        try await settle()

        #expect(provider.readCount == 0)
    }

    @Test("拖拽划选读取选区")
    func dragReadsSelection() async throws {
        let position = MousePositionBox(point: CGPoint(x: 100, y: 100))
        let (manager, monitor, provider) = makeManager(mouseLocation: { position.point })
        defer { manager.stopMonitoring() }

        monitor.handler?(mouseEvent(.leftMouseDown))
        position.point = CGPoint(x: 300, y: 140)
        monitor.handler?(mouseEvent(.leftMouseUp))
        try await settle()

        #expect(provider.readCount > 0)
    }

    @Test("双击选词读取选区")
    func doubleClickReadsSelection() async throws {
        let (manager, monitor, provider) = makeManager()
        defer { manager.stopMonitoring() }

        monitor.handler?(mouseEvent(.leftMouseDown, clickCount: 2))
        monitor.handler?(mouseEvent(.leftMouseUp, clickCount: 2))
        try await settle()

        #expect(provider.readCount > 0)
    }

    @Test("Shift+单击扩选读取选区")
    func shiftClickReadsSelection() async throws {
        let (manager, monitor, provider) = makeManager()
        defer { manager.stopMonitoring() }

        monitor.handler?(mouseEvent(.leftMouseDown, modifiers: [.shift]))
        monitor.handler?(mouseEvent(.leftMouseUp, modifiers: [.shift]))
        try await settle()

        #expect(provider.readCount > 0)
    }

    @Test("单击之后重新拖拽仍能触发")
    func dragAfterPlainClickStillTriggers() async throws {
        let position = MousePositionBox(point: CGPoint(x: 100, y: 100))
        let (manager, monitor, provider) = makeManager(mouseLocation: { position.point })
        defer { manager.stopMonitoring() }

        // 第一次单击：不触发，且按下位置被消费。
        monitor.handler?(mouseEvent(.leftMouseDown))
        monitor.handler?(mouseEvent(.leftMouseUp))
        try await settle()
        #expect(provider.readCount == 0)

        // 第二次拖拽：新的按下位置生效。
        position.point = CGPoint(x: 500, y: 500)
        monitor.handler?(mouseEvent(.leftMouseDown))
        position.point = CGPoint(x: 620, y: 520)
        monitor.handler?(mouseEvent(.leftMouseUp))
        try await settle()

        #expect(provider.readCount > 0)
    }

    @Test("没有按下位置时单击不触发")
    func mouseUpWithoutPressDoesNotTrigger() async throws {
        let (manager, monitor, provider) = makeManager()
        defer { manager.stopMonitoring() }

        // 监听刚启用、没捕获到 mouseDown 的场景。
        monitor.handler?(mouseEvent(.leftMouseUp))
        try await settle()

        #expect(provider.readCount == 0)
    }

    // MARK: 右键

    @Test("右键事件不触发读取，掩码不含右键")
    func rightClickNeverTriggers() async throws {
        let (manager, monitor, provider) = makeManager()
        defer { manager.stopMonitoring() }

        // 右键是上下文菜单手势：即使选区仍在也不得弹菜单。
        monitor.handler?(mouseEvent(.rightMouseUp))
        try await settle()

        #expect(provider.readCount == 0)
        let mask = try #require(monitor.lastMask)
        #expect(mask.contains(.leftMouseDown))
        #expect(mask.contains(.leftMouseUp))
        #expect(mask.contains(.keyUp))
        #expect(!mask.contains(.rightMouseUp))
        #expect(!mask.contains(.rightMouseDown))
    }

    // MARK: 键盘

    @Test("菜单不可见时 Cmd+C 的 keyUp 不读取选区")
    func copyKeyUpDoesNotReadSelection() async throws {
        let (manager, monitor, provider) = makeManager()
        defer { manager.stopMonitoring() }

        // 核心回归：选区仍在、菜单不在（如被滚动收起）时按 Cmd+C，
        // 旧实现会在 keyUp 重读选区并把菜单弹出来。
        monitor.handler?(keyUpEvent(keyCode: 8, modifiers: [.command]))
        try await settle()

        #expect(provider.readCount == 0)
    }

    @Test("菜单不可见时 Cmd+X 的 keyUp 不读取选区")
    func cutKeyUpDoesNotReadSelection() async throws {
        let (manager, monitor, provider) = makeManager()
        defer { manager.stopMonitoring() }

        monitor.handler?(keyUpEvent(keyCode: 7, modifiers: [.command]))
        try await settle()

        #expect(provider.readCount == 0)
    }

    @Test("非选择快捷键的 keyUp 不读取选区")
    func nonSelectionShortcutKeyUpDoesNotReadSelection() async throws {
        let (manager, monitor, provider) = makeManager()
        defer { manager.stopMonitoring() }

        // Cmd+S 等快捷键不产生选区，不得触发重读。
        monitor.handler?(keyUpEvent(keyCode: 1, modifiers: [.command]))
        try await settle()

        #expect(provider.readCount == 0)
    }

    @Test("Shift+方向键的 keyUp 读取选区")
    func shiftArrowKeyUpReadsSelection() async throws {
        let (manager, monitor, provider) = makeManager()
        defer { manager.stopMonitoring() }

        monitor.handler?(keyUpEvent(keyCode: 123, modifiers: [.shift]))
        try await settle()

        #expect(provider.readCount > 0)
    }

    @Test("Cmd+A 的 keyUp 读取选区")
    func selectAllKeyUpReadsSelection() async throws {
        let (manager, monitor, provider) = makeManager()
        defer { manager.stopMonitoring() }

        monitor.handler?(keyUpEvent(keyCode: 0, modifiers: [.command]))
        try await settle()

        #expect(provider.readCount > 0)
    }

    // MARK:  helpers

    private func makeManager(
        mouseLocation: @escaping () -> CGPoint = { CGPoint(x: 100, y: 100) }
    ) -> (TextSelectionManager, CapturingTextEventMonitor, CountingSelectedTextProvider) {
        let monitor = CapturingTextEventMonitor()
        let provider = CountingSelectedTextProvider()
        let manager = TextSelectionManager(
            eventMonitor: monitor,
            selectedTextProvider: provider,
            permissionChecker: { true },
            mouseLocationProvider: mouseLocation
        )
        manager.startMonitoring()
        return (manager, monitor, provider)
    }

    /// 等待监听回调的 MainActor 跳转与首次选区读取（60ms 延迟）落地。
    private func settle() async throws {
        try await Task.sleep(for: .milliseconds(200))
    }

    private func mouseEvent(
        _ type: NSEvent.EventType,
        clickCount: Int = 1,
        modifiers: NSEvent.ModifierFlags = []
    ) -> NSEvent {
        NSEvent.mouseEvent(
            with: type,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: clickCount,
            pressure: 1
        )!
    }

    private func keyUpEvent(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyUp,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: keyCode
        )!
    }
}

// MARK: - 测试替身

/// 可变鼠标位置：拖拽测试里按下与抬起位于不同坐标。
private final class MousePositionBox {
    var point: CGPoint
    init(point: CGPoint) { self.point = point }
}

/// 捕获监听回调与掩码，不注册真实的全局事件监听。
@MainActor
private final class CapturingTextEventMonitor: TextEventMonitoring {
    private(set) var handler: ((NSEvent) -> Void)?
    private(set) var lastMask: NSEvent.EventTypeMask?

    func addGlobalMonitor(
        matching mask: NSEvent.EventTypeMask,
        handler: @escaping (NSEvent) -> Void
    ) -> Any? {
        lastMask = mask
        self.handler = handler
        return NSObject()
    }

    func removeMonitor(_ monitor: Any) {}
}

/// 只计数、恒返回 nil：守住「是否触发读取」，不构造真实浮层。
@MainActor
private final class CountingSelectedTextProvider: SelectedTextProviding {
    private(set) var readCount = 0

    func readSelectedText(anchor: CGPoint) async -> SelectedText? {
        readCount += 1
        return nil
    }
}