import AppKit
import Testing
@testable import LumiPreviewKit

@MainActor
@Suite("LiveCanvasService")
struct LiveCanvasServiceTests {

    @Test("应用失焦时保持显示，恢复时重新同步 frame")
    func resignAndBecomeKeyKeepVisibility() async throws {
        let service = LumiPreviewFacade.LiveCanvasService(displayMode: .live)
        var events: [String] = []

        service.onShowLivePreview = { _ in
            events.append("show")
        }
        service.onHideLivePreview = { _ in
            events.append("hide")
        }
        service.onSyncLiveFrameFromEngine = { _ in }

        service.updateLiveCanvasRect(CGRect(x: 10, y: 20, width: 300, height: 200), scale: 2)
        service.liveCanvasDidAppear()
        try await waitForAsyncCallbacks()

        service.lumiWindowDidResignKey()
        try await waitForAsyncCallbacks()
        #expect(events == ["show"])
        #expect(service.shouldShowLiveWindow)

        events.removeAll()
        service.lumiWindowDidBecomeKey()
        try await waitForAsyncCallbacks()

        #expect(events == ["show"])
        #expect(service.shouldShowLiveWindow)
    }

    @Test("连续焦点变化不会隐藏 Live 预览")
    func focusChangesKeepVisibility() async throws {
        let service = LumiPreviewFacade.LiveCanvasService(displayMode: .live)
        var events: [String] = []

        service.onShowLivePreview = { _ in
            events.append("show")
        }
        service.onHideLivePreview = { _ in
            events.append("hide")
        }
        service.onSyncLiveFrameFromEngine = { _ in }

        service.updateLiveCanvasRect(CGRect(x: 10, y: 20, width: 300, height: 200), scale: 2)
        service.liveCanvasDidAppear()
        try await waitForAsyncCallbacks()

        events.removeAll()
        service.lumiWindowDidResignKey()
        service.lumiWindowDidBecomeKey()
        service.lumiWindowDidResignKey()
        try await waitForAsyncCallbacks()

        #expect(!events.contains("hide"))
        #expect(service.shouldShowLiveWindow)
    }

    @Test("预览窗口 active 状态变化不隐藏 Live 预览")
    func previewWindowActiveStateChangesKeepVisibility() async throws {
        let service = LumiPreviewFacade.LiveCanvasService(displayMode: .live)
        var events: [String] = []

        service.onShowLivePreview = { _ in
            events.append("show")
        }
        service.onHideLivePreview = { _ in
            events.append("hide")
        }
        service.onSyncLiveFrameFromEngine = { _ in }

        service.updateLiveCanvasRect(CGRect(x: 0, y: 0, width: 320, height: 180), scale: 1)
        service.liveCanvasDidAppear()
        try await waitForAsyncCallbacks()

        service.previewWindowDidBecomeInactive()
        try await waitForAsyncCallbacks()

        service.previewWindowDidBecomeActive()
        try await waitForAsyncCallbacks()

        #expect(!events.contains("hide"))
        #expect(service.shouldShowLiveWindow)
    }

    @Test("短暂 frame unavailable 不隐藏 Live 预览")
    func transientFrameUnavailableKeepsVisibility() async throws {
        let service = LumiPreviewFacade.LiveCanvasService(displayMode: .live)
        let frame = CGRect(x: 12, y: 24, width: 320, height: 180)
        var events: [String] = []

        service.onShowLivePreview = { _ in
            events.append("show")
        }
        service.onHideLivePreview = { _ in
            events.append("hide")
        }
        service.onSyncLiveFrameFromEngine = { _ in }

        service.updateLiveCanvasRect(frame, scale: 2)
        service.liveCanvasDidAppear()
        try await waitForAsyncCallbacks()

        events.removeAll()
        service.liveCanvasFrameUnavailable()
        try await waitForAsyncCallbacks()

        #expect(!events.contains("hide"))
        #expect(service.shouldShowLiveWindow)
        #expect(service.liveCanvasRect == frame)
    }

    @Test("相同 frame 不重复触发同步，显著变化才触发")
    func identicalFrameDoesNotResync() async throws {
        let service = LumiPreviewFacade.LiveCanvasService(displayMode: .live)
        var syncCount = 0

        service.onSyncLiveFrameFromEngine = { _ in
            syncCount += 1
        }

        service.updateLiveCanvasRect(CGRect(x: 10, y: 20, width: 300, height: 200), scale: 2)
        try await waitForAsyncCallbacks()
        #expect(syncCount == 1)

        service.updateLiveCanvasRect(CGRect(x: 10.2, y: 20.2, width: 300.1, height: 200.1), scale: 2)
        try await waitForAsyncCallbacks()
        #expect(syncCount == 1)

        service.updateLiveCanvasRect(CGRect(x: 14, y: 20, width: 300, height: 200), scale: 2)
        try await waitForAsyncCallbacks()
        #expect(syncCount == 2)
    }

    @Test("image 模式下可见性事件不驱动 live window")
    func imageModeSuppressesVisibilityCallbacks() async throws {
        let service = LumiPreviewFacade.LiveCanvasService(displayMode: .image)
        var showCount = 0
        var hideCount = 0

        service.onShowLivePreview = { _ in
            showCount += 1
        }
        service.onHideLivePreview = { _ in
            hideCount += 1
        }

        service.updateLiveCanvasRect(CGRect(x: 0, y: 0, width: 320, height: 180), scale: 1)
        service.liveCanvasDidAppear()
        service.lumiWindowDidResignKey()
        service.previewWindowDidBecomeInactive()
        try await waitForAsyncCallbacks()

        #expect(showCount == 0)
        #expect(hideCount == 0)
        #expect(!service.shouldShowLiveWindow)
    }

    @Test("canvas 消失和窗口最小化都会隐藏 live window")
    func canvasDisappearAndMiniaturizeHideLiveWindow() async throws {
        let service = LumiPreviewFacade.LiveCanvasService(displayMode: .live)
        var events: [String] = []
        var hideReasons: [String] = []

        service.onShowLivePreview = { _ in
            events.append("show")
        }
        service.onHideLivePreview = { reason in
            events.append("hide")
            hideReasons.append(reason)
        }
        service.onSyncLiveFrameFromEngine = { _ in }

        service.updateLiveCanvasRect(CGRect(x: 0, y: 0, width: 320, height: 180), scale: 1)
        service.liveCanvasDidAppear()
        try await waitForAsyncCallbacks()

        service.liveCanvasDidDisappear()
        try await waitForAsyncCallbacks()

        service.updateLiveCanvasRect(CGRect(x: 0, y: 0, width: 320, height: 180), scale: 1)
        service.liveCanvasDidAppear()
        try await waitForAsyncCallbacks()

        service.lumiWindowDidMiniaturizeOrClose()
        try await waitForAsyncCallbacks()

        #expect(events == ["show", "hide", "show", "hide"])
        #expect(hideReasons == ["live canvas disappeared", "Lumi window minimized or closed"])
        #expect(!service.shouldShowLiveWindow)
    }

    @Test("切换 panel tab 后隐藏，画布恢复可见后再显示")
    func panelTabSwitchHidesUntilCanvasVisibleAgain() async throws {
        let service = LumiPreviewFacade.LiveCanvasService(displayMode: .live)
        var events: [String] = []

        service.onShowLivePreview = { _ in
            events.append("show")
        }
        service.onHideLivePreview = { _ in
            events.append("hide")
        }
        service.onSyncLiveFrameFromEngine = { _ in }

        service.updateLiveCanvasRect(CGRect(x: 0, y: 0, width: 320, height: 180), scale: 2)
        service.liveCanvasDidAppear()
        try await waitForAsyncCallbacks()

        service.liveCanvasDidDisappear()
        try await waitForAsyncCallbacks()

        #expect(events.last == "hide")
        #expect(!service.shouldShowLiveWindow)

        service.liveCanvasDidAppear()
        try await waitForAsyncCallbacks()

        #expect(events.last == "show")
        #expect(events.filter { $0 == "show" }.count == 2)
        #expect(events.filter { $0 == "hide" }.count >= 1)
        #expect(service.shouldShowLiveWindow)

        service.previewWindowDidBecomeActive()
        try await waitForAsyncCallbacks()

        #expect(events.last == "show")
        #expect(events.filter { $0 == "show" }.count == 3)
        #expect(service.shouldShowLiveWindow)
    }

    @Test("重新激活前台时同步 frame 且保持显示")
    func appReactivationResyncsFrameWithoutHiding() async throws {
        let service = LumiPreviewFacade.LiveCanvasService(displayMode: .live)
        var events: [String] = []

        service.onSyncLiveFrameFromEngine = { _ in
            events.append("sync")
        }
        service.onShowLivePreview = { _ in
            events.append("show")
        }
        service.onHideLivePreview = { _ in
            events.append("hide")
        }

        service.updateLiveCanvasRect(CGRect(x: 0, y: 0, width: 320, height: 180), scale: 2)
        service.liveCanvasDidAppear()
        try await waitForAsyncCallbacks()
        events.removeAll()

        service.lumiWindowDidResignKey()
        try await waitForAsyncCallbacks()
        #expect(events.isEmpty)
        #expect(service.shouldShowLiveWindow)

        events.removeAll()
        service.lumiWindowDidBecomeKey()
        try await waitForAsyncCallbacks()

        #expect(events == ["sync", "show"])
        #expect(service.shouldShowLiveWindow)
    }

    @Test("重新激活前台时使用最新 frame 保持位置")
    func appReactivationUsesLatestFrame() async throws {
        let service = LumiPreviewFacade.LiveCanvasService(displayMode: .live)
        let initialRect = CGRect(x: 10, y: 20, width: 320, height: 180)
        let movedRect = CGRect(x: 120, y: 80, width: 420, height: 240)
        var syncRects: [CGRect] = []
        var events: [String] = []

        service.onSyncLiveFrameFromEngine = { _ in
            syncRects.append(service.liveCanvasRect)
            events.append("sync")
        }
        service.onShowLivePreview = { _ in
            events.append("show")
        }
        service.onHideLivePreview = { _ in
            events.append("hide")
        }

        service.updateLiveCanvasRect(initialRect, scale: 2)
        service.liveCanvasDidAppear()
        try await waitForAsyncCallbacks()

        service.lumiWindowDidResignKey()
        try await waitForAsyncCallbacks()

        syncRects.removeAll()
        events.removeAll()

        service.updateLiveCanvasRect(movedRect, scale: 2)
        try await waitForAsyncCallbacks()

        #expect(syncRects == [movedRect])
        #expect(events == ["sync"])
        #expect(service.liveCanvasRect == movedRect)

        syncRects.removeAll()
        events.removeAll()

        service.lumiWindowDidBecomeKey()
        try await waitForAsyncCallbacks()

        #expect(syncRects == [movedRect])
        #expect(events == ["sync", "show"])
        #expect(service.shouldShowLiveWindow)
        #expect(service.liveCanvasRect == movedRect)
    }

    @Test("连续 resize 时仅同步最后一个 frame")
    func rapidResizeCoalescesToLatestFrame() async throws {
        let service = LumiPreviewFacade.LiveCanvasService(displayMode: .live)
        let initialRect = CGRect(x: 0, y: 0, width: 320, height: 180)
        let intermediateRect = CGRect(x: 0, y: 0, width: 480, height: 220)
        let finalRect = CGRect(x: 0, y: 0, width: 640, height: 300)
        var syncRects: [CGRect] = []
        var events: [String] = []

        service.onSyncLiveFrameFromEngine = { _ in
            syncRects.append(service.liveCanvasRect)
            events.append("sync")
        }
        service.onShowLivePreview = { _ in
            events.append("show")
        }
        service.onHideLivePreview = { _ in
            events.append("hide")
        }

        service.updateLiveCanvasRect(initialRect, scale: 2)
        service.liveCanvasDidAppear()
        try await waitForAsyncCallbacks()

        syncRects.removeAll()
        events.removeAll()

        service.updateLiveCanvasRect(intermediateRect, scale: 2)
        service.updateLiveCanvasRect(finalRect, scale: 2)
        try await waitForAsyncCallbacks()

        #expect(syncRects == [finalRect])
        #expect(events == ["sync"])
        #expect(service.liveCanvasRect == finalRect)
        #expect(service.shouldShowLiveWindow)
    }

    @Test("连续拖动主窗口时仅同步最后位置且不隐藏")
    func rapidMoveCoalescesToLatestFrameWithoutHiding() async throws {
        let service = LumiPreviewFacade.LiveCanvasService(displayMode: .live)
        let initialRect = CGRect(x: 40, y: 60, width: 320, height: 180)
        let movedRect1 = CGRect(x: 140, y: 120, width: 320, height: 180)
        let movedRect2 = CGRect(x: 260, y: 210, width: 320, height: 180)
        var syncRects: [CGRect] = []
        var events: [String] = []

        service.onSyncLiveFrameFromEngine = { _ in
            syncRects.append(service.liveCanvasRect)
            events.append("sync")
        }
        service.onShowLivePreview = { _ in
            events.append("show")
        }
        service.onHideLivePreview = { _ in
            events.append("hide")
        }

        service.updateLiveCanvasRect(initialRect, scale: 2)
        service.liveCanvasDidAppear()
        try await waitForAsyncCallbacks()

        syncRects.removeAll()
        events.removeAll()

        service.updateLiveCanvasRect(movedRect1, scale: 2)
        service.updateLiveCanvasRect(movedRect2, scale: 2)
        try await waitForAsyncCallbacks()

        #expect(syncRects == [movedRect2])
        #expect(events == ["sync"])
        #expect(service.liveCanvasRect == movedRect2)
        #expect(service.shouldShowLiveWindow)
    }

    private func waitForAsyncCallbacks() async throws {
        try await Task.sleep(nanoseconds: 80_000_000)
    }
}
