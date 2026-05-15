import Foundation
import AppKit
import Testing
@testable import LumiPreviewKit

@Suite("PreviewDisplayMode")
struct PreviewDisplayModeTests {

    // MARK: - Display Mode Model

    @Test("PreviewDisplayMode 包含 image 和 live 两个值")
    func displayModeHasExpectedCases() {
        #expect(LumiPreviewFacade.PreviewDisplayMode.allCases.count == 2)
        #expect(LumiPreviewFacade.PreviewDisplayMode.image.rawValue == "image")
        #expect(LumiPreviewFacade.PreviewDisplayMode.live.rawValue == "live")
    }

    @Test("LivePreviewState 包含所有预期状态")
    func livePreviewStateHasExpectedCases() {
        let states: [LumiPreviewFacade.LivePreviewState] = [
            .unavailable, .available, .launching, .running, .failed, .stopped
        ]
        #expect(states.count == 6)
        #expect(LumiPreviewFacade.LivePreviewState.unavailable.rawValue == "unavailable")
        #expect(LumiPreviewFacade.LivePreviewState.available.rawValue == "available")
        #expect(LumiPreviewFacade.LivePreviewState.launching.rawValue == "launching")
        #expect(LumiPreviewFacade.LivePreviewState.running.rawValue == "running")
        #expect(LumiPreviewFacade.LivePreviewState.failed.rawValue == "failed")
        #expect(LumiPreviewFacade.LivePreviewState.stopped.rawValue == "stopped")
    }

    @Test("LivePreviewInfo 默认状态为 unavailable")
    func livePreviewInfoDefaults() {
        let info = LumiPreviewFacade.LivePreviewInfo()
        #expect(info.state == .unavailable)
        #expect(info.unavailableReason == nil)
        #expect(info.hostWindowNumber == nil)
        #expect(info.hostProcessID == nil)
    }

    @Test("LivePreviewInfo 可编码和解码")
    func livePreviewInfoCoding() throws {
        let info = LumiPreviewFacade.LivePreviewInfo(
            state: .running,
            unavailableReason: nil,
            hostWindowNumber: 42,
            hostProcessID: 12345
        )
        let data = try JSONEncoder().encode(info)
        let decoded = try JSONDecoder().decode(LumiPreviewFacade.LivePreviewInfo.self, from: data)

        #expect(decoded.state == .running)
        #expect(decoded.unavailableReason == nil)
        #expect(decoded.hostWindowNumber == 42)
        #expect(decoded.hostProcessID == 12345)
    }

    @Test("PreviewDisplayMode 可编码和解码")
    func displayModeCoding() throws {
        for mode in LumiPreviewFacade.PreviewDisplayMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(LumiPreviewFacade.PreviewDisplayMode.self, from: data)
            #expect(decoded == mode)
        }
    }

    @Test("PreviewPerformanceMetrics 记录 build、load 和 refresh 指标")
    func performanceMetricsRecordsBuildLoadAndRefresh() async {
        let session = LumiPreviewFacade.HotPreviewSession(
            discovery: LumiPreviewFacade.PreviewDiscovery(
                id: "test-performance",
                title: "Test",
                sourceFileURL: URL(fileURLWithPath: "/tmp/Test.swift"),
                lineNumber: 1,
                endLineNumber: 3
            )
        )

        await session.recordCompile(duration: 1.2, usedCache: true)
        await session.recordLoad(duration: 0.3)
        await session.recordRefresh(duration: 1.6)

        let metrics = await session.performanceMetrics
        #expect(metrics.lastCompileDuration == 1.2)
        #expect(metrics.lastLoadDuration == 0.3)
        #expect(metrics.lastRefreshDuration == 1.6)
        #expect(metrics.lastCompileUsedCache == true)
    }

    // MARK: - Session Display Mode

    @Test("HotPreviewSession 默认显示模式为 image")
    func sessionDefaultDisplayModeIsImage() async {
        let session = LumiPreviewFacade.HotPreviewSession(
            discovery: LumiPreviewFacade.PreviewDiscovery(
                id: "test-1",
                title: "Test",
                sourceFileURL: URL(fileURLWithPath: "/tmp/Test.swift"),
                lineNumber: 1,
                endLineNumber: 3
            )
        )
        #expect(await session.displayMode == .image)
        #expect(await session.livePreviewInfo.state == .unavailable)
    }

    @Test("切换显示模式后 session 状态正确变化")
    func switchDisplayModeChangesSessionState() async {
        let session = LumiPreviewFacade.HotPreviewSession(
            discovery: LumiPreviewFacade.PreviewDiscovery(
                id: "test-2",
                title: "Test",
                sourceFileURL: URL(fileURLWithPath: "/tmp/Test.swift"),
                lineNumber: 1,
                endLineNumber: 3
            )
        )

        // 默认是 image
        #expect(await session.displayMode == .image)

        // 切换到 live
        await session.setDisplayMode(.live)
        #expect(await session.displayMode == .live)

        // 切回 image
        await session.setDisplayMode(.image)
        #expect(await session.displayMode == .image)
    }

    @Test("markLivePreviewAvailable 设置 live 状态为 available")
    func markLivePreviewAvailableSetsState() async {
        let session = LumiPreviewFacade.HotPreviewSession(
            discovery: LumiPreviewFacade.PreviewDiscovery(
                id: "test-3",
                title: "Test",
                sourceFileURL: URL(fileURLWithPath: "/tmp/Test.swift"),
                lineNumber: 1,
                endLineNumber: 3
            )
        )

        #expect(await session.livePreviewInfo.state == .unavailable)

        await session.markLivePreviewAvailable(windowNumber: 123)
        #expect(await session.livePreviewInfo.state == .available)
        #expect(await session.livePreviewInfo.hostWindowNumber == 123)
    }

    @Test("fallbackToImageMode 降级到 image 并记录原因")
    func fallbackToImageModeDegradesCorrectly() async {
        let session = LumiPreviewFacade.HotPreviewSession(
            discovery: LumiPreviewFacade.PreviewDiscovery(
                id: "test-4",
                title: "Test",
                sourceFileURL: URL(fileURLWithPath: "/tmp/Test.swift"),
                lineNumber: 1,
                endLineNumber: 3
            )
        )

        // 先设置为 live 模式
        await session.setDisplayMode(.live)
        await session.markLivePreviewAvailable()
        #expect(await session.displayMode == .live)
        #expect(await session.livePreviewInfo.state == .available)

        // 降级
        await session.fallbackToImageMode(reason: "Host window creation failed")
        #expect(await session.displayMode == .image)
        #expect(await session.livePreviewInfo.state == .failed)
        #expect(await session.livePreviewInfo.unavailableReason == "Host window creation failed")
    }

    @Test("setLivePreviewInfo 更新完整信息")
    func setLivePreviewInfoUpdatesFullState() async {
        let session = LumiPreviewFacade.HotPreviewSession(
            discovery: LumiPreviewFacade.PreviewDiscovery(
                id: "test-5",
                title: "Test",
                sourceFileURL: URL(fileURLWithPath: "/tmp/Test.swift"),
                lineNumber: 1,
                endLineNumber: 3
            )
        )

        let info = LumiPreviewFacade.LivePreviewInfo(
            state: .running,
            unavailableReason: nil,
            hostWindowNumber: 456,
            hostProcessID: 789
        )
        await session.setLivePreviewInfo(info)
        #expect(await session.livePreviewInfo.state == .running)
        #expect(await session.livePreviewInfo.hostWindowNumber == 456)
        #expect(await session.livePreviewInfo.hostProcessID == 789)
    }

    @Test("markLivePreviewRunning 设置 running 状态")
    func markLivePreviewRunningSetsState() async {
        let session = LumiPreviewFacade.HotPreviewSession(
            discovery: LumiPreviewFacade.PreviewDiscovery(
                id: "test-running",
                title: "Test",
                sourceFileURL: URL(fileURLWithPath: "/tmp/Test.swift"),
                lineNumber: 1,
                endLineNumber: 3
            )
        )

        await session.markLivePreviewRunning(windowNumber: 11, hostProcessID: 20)

        #expect(await session.livePreviewInfo.state == .running)
        #expect(await session.livePreviewInfo.hostWindowNumber == 11)
        #expect(await session.livePreviewInfo.hostProcessID == 20)
    }

    @Test("PreviewEntryBuilder 清理过期缓存并保留新缓存")
    func previewEntryBuilderRemovesExpiredCacheEntries() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewKitTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let oldEntry = root.appendingPathComponent("old", isDirectory: true)
        let newEntry = root.appendingPathComponent("new", isDirectory: true)
        try FileManager.default.createDirectory(at: oldEntry, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: newEntry, withIntermediateDirectories: true)

        let now = Date()
        try FileManager.default.setAttributes(
            [.modificationDate: now.addingTimeInterval(-8 * 24 * 60 * 60)],
            ofItemAtPath: oldEntry.path
        )
        try FileManager.default.setAttributes(
            [.modificationDate: now],
            ofItemAtPath: newEntry.path
        )

        LumiPreviewFacade.PreviewEntryBuilder.removeExpiredCacheEntries(
            olderThan: 7 * 24 * 60 * 60,
            keepingNewest: 64,
            rootDirectory: root,
            now: now
        )

        #expect(!FileManager.default.fileExists(atPath: oldEntry.path))
        #expect(FileManager.default.fileExists(atPath: newEntry.path))
    }

    @Test("updateDiscovery 替换会话中的预览发现结果")
    func updateDiscoveryReplacesSessionDiscovery() async {
        let original = LumiPreviewFacade.PreviewDiscovery(
            id: "original",
            title: "Original",
            sourceFileURL: URL(fileURLWithPath: "/tmp/Original.swift"),
            lineNumber: 1,
            endLineNumber: 3
        )
        let updated = LumiPreviewFacade.PreviewDiscovery(
            id: "updated",
            title: "Updated",
            sourceFileURL: URL(fileURLWithPath: "/tmp/Updated.swift"),
            lineNumber: 4,
            endLineNumber: 6
        )
        let session = LumiPreviewFacade.HotPreviewSession(discovery: original)

        await session.updateDiscovery(updated)
        let discovery = await session.discovery

        #expect(discovery.id == updated.id)
        #expect(discovery.title == updated.title)
        #expect(discovery.sourceFileURL == updated.sourceFileURL)
        #expect(discovery.lineNumber == updated.lineNumber)
        #expect(discovery.endLineNumber == updated.endLineNumber)
    }

    // MARK: - LumiPreviewFacade.RenderResponse Live Fields

    @Test("RenderResponse 新增 livePreviewEnabled 和 liveWindowNumber 字段")
    func renderResponseLiveFields() throws {
        let response = LumiPreviewFacade.RenderResponse(
            success: true,
            message: "Loaded preview view entry Test",
            livePreviewEnabled: true,
            liveWindowNumber: 789
        )

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(LumiPreviewFacade.RenderResponse.self, from: data)

        #expect(decoded.livePreviewEnabled == true)
        #expect(decoded.liveWindowNumber == 789)
    }

    @Test("RenderResponse 默认 livePreviewEnabled 为 false")
    func renderResponseDefaultLiveFields() throws {
        let response = LumiPreviewFacade.RenderResponse(success: true)

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(LumiPreviewFacade.RenderResponse.self, from: data)

        #expect(decoded.livePreviewEnabled == false)
        #expect(decoded.liveWindowNumber == nil)
    }

    @Test("旧格式 JSON 解码时 livePreviewEnabled 默认为 false")
    func renderResponseBackwardCompatibility() throws {
        let json = """
        {"success":true,"message":"Loaded preview"}
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode(LumiPreviewFacade.RenderResponse.self, from: data)

        #expect(decoded.success == true)
        #expect(decoded.livePreviewEnabled == false)
        #expect(decoded.liveWindowNumber == nil)
    }

    // MARK: - LumiPreviewFacade.LiveFrameRequest

    @Test("LiveFrameRequest 可编码和解码")
    func liveFrameRequestCoding() throws {
        let frame = LumiPreviewFacade.LiveFrameRequest(x: 100.0, y: 200.0, width: 320.0, height: 180.0, scale: 2)
        let data = try JSONEncoder().encode(frame)
        let decoded = try JSONDecoder().decode(LumiPreviewFacade.LiveFrameRequest.self, from: data)

        #expect(decoded.x == 100.0)
        #expect(decoded.y == 200.0)
        #expect(decoded.width == 320.0)
        #expect(decoded.height == 180.0)
        #expect(decoded.scale == 2)
    }

    @Test("旧格式 LumiPreviewFacade.LiveFrameRequest 解码时 scale 默认为 1")
    func liveFrameRequestLegacyCodingDefaultsScale() throws {
        let data = #"{"x":100,"y":200,"width":320,"height":180}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(LumiPreviewFacade.LiveFrameRequest.self, from: data)

        #expect(decoded.scale == 1)
    }

    @Test("RenderRequest 携带 liveFrame")
    func renderRequestWithLiveFrame() throws {
        let frame = LumiPreviewFacade.LiveFrameRequest(x: 50, y: 100, width: 640, height: 480)
        let request = LumiPreviewFacade.RenderRequest(
            command: .updateLiveFrame,
            liveFrame: frame
        )

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(LumiPreviewFacade.RenderRequest.self, from: data)

        #expect(decoded.command == .updateLiveFrame)
        #expect(decoded.liveFrame?.x == 50)
        #expect(decoded.liveFrame?.y == 100)
        #expect(decoded.liveFrame?.width == 640)
        #expect(decoded.liveFrame?.height == 480)
    }

    // MARK: - LumiPreviewFacade.PreviewHostCommand Live Commands

    @Test("PreviewHostCommand 包含所有 Live 命令")
    func hostCommandIncludesLiveCommands() {
        let liveCommands: [LumiPreviewFacade.PreviewHostCommand] = [
            .startLivePreview,
            .updateLiveFrame,
            .showLivePreview,
            .hideLivePreview,
            .reloadLivePreview,
            .stopLivePreview
        ]

        for command in liveCommands {
            let rawValue = command.rawValue
            let reconstructed = LumiPreviewFacade.PreviewHostCommand(rawValue: rawValue)
            #expect(reconstructed == command)
        }
    }

    @MainActor
    @Test("LivePreviewWindow 不吞掉 Command 快捷键")
    func livePreviewWindowDoesNotConsumeCommandShortcut() {
        let window = LivePreviewWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 180))
        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command],
            timestamp: 0,
            windowNumber: window.windowNumber,
            context: nil,
            characters: "s",
            charactersIgnoringModifiers: "s",
            isARepeat: false,
            keyCode: 1
        )

        #expect(event != nil)
        #expect(window.performKeyEquivalent(with: event!) == false)
    }

    @MainActor
    @Test("LivePreviewWindow 由主 app 显隐控制且不提升层级")
    func livePreviewWindowUsesMainAppVisibilityControlAtNormalLevel() {
        let window = LivePreviewWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 180))

        #expect(!window.hidesOnDeactivate)
        #expect(window.level == .normal)
        #expect(window.styleMask.contains(.nonactivatingPanel))
        #expect(window.collectionBehavior == [.fullScreenAuxiliary])
    }

    @MainActor
    @Test("LivePreviewWindow 内按钮可点击并改变状态")
    func livePreviewWindowSupportsButtonInteraction() {
        let window = LivePreviewWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 180))
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 180))
        let button = NSButton(checkboxWithTitle: "Toggle", target: nil, action: nil)
        button.frame = NSRect(x: 20, y: 20, width: 120, height: 24)
        container.addSubview(button)
        window.contentView = container

        #expect(button.state == .off)

        window.orderFront(nil)
        button.performClick(nil)

        #expect(button.state == .on)
    }

    @MainActor
    @Test("LivePreviewWindow 内滚动视图可滚动")
    func livePreviewWindowSupportsScrollingContent() {
        let window = LivePreviewWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 180))
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 320, height: 180))
        let documentView = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 720))

        scrollView.hasVerticalScroller = true
        scrollView.documentView = documentView
        window.contentView = scrollView
        window.orderFront(nil)
        scrollView.layoutSubtreeIfNeeded()

        let initialOrigin = scrollView.contentView.bounds.origin.y
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: 180))
        scrollView.reflectScrolledClipView(scrollView.contentView)

        #expect(scrollView.contentView.bounds.origin.y > initialOrigin)
    }

    @MainActor
    @Test("LivePreviewWindow 规范化并隐藏 child window")
    func livePreviewWindowNormalizesAndHidesChildWindows() {
        let parent = LivePreviewWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 180))
        let child = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 80),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )

        parent.addChildWindow(child, ordered: .above)
        #expect(child.level == parent.level)
        #expect(child.collectionBehavior.contains(.fullScreenAuxiliary))

        parent.orderFront(nil)
        parent.orderOut(nil)

        #expect(!child.isVisible)
    }

}

private extension PreviewDisplayModeTests {
    func XCTUnwrap(_ optional: Optional<Data>) throws -> Data {
        guard let value = optional else {
            throw LumiPreviewFacade.PreviewError.runtimeCrashed(message: "Unexpected nil")
        }
        return value
    }
}
