import Foundation
import Testing
@testable import LumiPreviewKit

@Suite("PreviewDisplayMode")
struct PreviewDisplayModeTests {

    // MARK: - Display Mode Model

    @Test("PreviewDisplayMode 包含 image 和 live 两个值")
    func displayModeHasExpectedCases() {
        #expect(PreviewDisplayMode.allCases.count == 2)
        #expect(PreviewDisplayMode.image.rawValue == "image")
        #expect(PreviewDisplayMode.live.rawValue == "live")
    }

    @Test("LivePreviewState 包含所有预期状态")
    func livePreviewStateHasExpectedCases() {
        let states: [LivePreviewState] = [
            .unavailable, .available, .launching, .running, .failed, .stopped
        ]
        #expect(states.count == 6)
        #expect(LivePreviewState.unavailable.rawValue == "unavailable")
        #expect(LivePreviewState.available.rawValue == "available")
        #expect(LivePreviewState.launching.rawValue == "launching")
        #expect(LivePreviewState.running.rawValue == "running")
        #expect(LivePreviewState.failed.rawValue == "failed")
        #expect(LivePreviewState.stopped.rawValue == "stopped")
    }

    @Test("LivePreviewInfo 默认状态为 unavailable")
    func livePreviewInfoDefaults() {
        let info = LivePreviewInfo()
        #expect(info.state == .unavailable)
        #expect(info.unavailableReason == nil)
        #expect(info.hostWindowNumber == nil)
    }

    @Test("LivePreviewInfo 可编码和解码")
    func livePreviewInfoCoding() throws {
        let info = LivePreviewInfo(
            state: .running,
            unavailableReason: nil,
            hostWindowNumber: 42
        )
        let data = try JSONEncoder().encode(info)
        let decoded = try JSONDecoder().decode(LivePreviewInfo.self, from: data)

        #expect(decoded.state == .running)
        #expect(decoded.unavailableReason == nil)
        #expect(decoded.hostWindowNumber == 42)
    }

    @Test("PreviewDisplayMode 可编码和解码")
    func displayModeCoding() throws {
        for mode in PreviewDisplayMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(PreviewDisplayMode.self, from: data)
            #expect(decoded == mode)
        }
    }

    // MARK: - Session Display Mode

    @Test("LivePreviewSession 默认显示模式为 image")
    func sessionDefaultDisplayModeIsImage() async {
        let session = LivePreviewSession(
            discovery: PreviewDiscovery(
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
        let session = LivePreviewSession(
            discovery: PreviewDiscovery(
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
        let session = LivePreviewSession(
            discovery: PreviewDiscovery(
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
        let session = LivePreviewSession(
            discovery: PreviewDiscovery(
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
        let session = LivePreviewSession(
            discovery: PreviewDiscovery(
                id: "test-5",
                title: "Test",
                sourceFileURL: URL(fileURLWithPath: "/tmp/Test.swift"),
                lineNumber: 1,
                endLineNumber: 3
            )
        )

        let info = LivePreviewInfo(
            state: .running,
            unavailableReason: nil,
            hostWindowNumber: 456
        )
        await session.setLivePreviewInfo(info)
        #expect(await session.livePreviewInfo.state == .running)
        #expect(await session.livePreviewInfo.hostWindowNumber == 456)
    }

    @Test("markLivePreviewAvailable 不会把 running 降级为 available")
    func markLivePreviewAvailablePreservesRunningState() async {
        let session = LivePreviewSession(
            discovery: PreviewDiscovery(
                id: "test-running",
                title: "Test",
                sourceFileURL: URL(fileURLWithPath: "/tmp/Test.swift"),
                lineNumber: 1,
                endLineNumber: 3
            )
        )

        await session.setLivePreviewInfo(LivePreviewInfo(state: .running, hostWindowNumber: 10))
        await session.markLivePreviewAvailable(windowNumber: 11)

        #expect(await session.livePreviewInfo.state == .running)
        #expect(await session.livePreviewInfo.hostWindowNumber == 11)
    }

    @Test("updateDiscovery 替换会话中的预览发现结果")
    func updateDiscoveryReplacesSessionDiscovery() async {
        let original = PreviewDiscovery(
            id: "original",
            title: "Original",
            sourceFileURL: URL(fileURLWithPath: "/tmp/Original.swift"),
            lineNumber: 1,
            endLineNumber: 3
        )
        let updated = PreviewDiscovery(
            id: "updated",
            title: "Updated",
            sourceFileURL: URL(fileURLWithPath: "/tmp/Updated.swift"),
            lineNumber: 4,
            endLineNumber: 6
        )
        let session = LivePreviewSession(discovery: original)

        await session.updateDiscovery(updated)
        let discovery = await session.discovery

        #expect(discovery.id == updated.id)
        #expect(discovery.title == updated.title)
        #expect(discovery.sourceFileURL == updated.sourceFileURL)
        #expect(discovery.lineNumber == updated.lineNumber)
        #expect(discovery.endLineNumber == updated.endLineNumber)
    }

    // MARK: - RenderResponse Live Fields

    @Test("RenderResponse 新增 livePreviewEnabled 和 liveWindowNumber 字段")
    func renderResponseLiveFields() throws {
        let response = RenderResponse(
            success: true,
            message: "Loaded preview view entry Test",
            livePreviewEnabled: true,
            liveWindowNumber: 789
        )

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(RenderResponse.self, from: data)

        #expect(decoded.livePreviewEnabled == true)
        #expect(decoded.liveWindowNumber == 789)
    }

    @Test("RenderResponse 默认 livePreviewEnabled 为 false")
    func renderResponseDefaultLiveFields() throws {
        let response = RenderResponse(success: true)

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(RenderResponse.self, from: data)

        #expect(decoded.livePreviewEnabled == false)
        #expect(decoded.liveWindowNumber == nil)
    }

    @Test("旧格式 JSON 解码时 livePreviewEnabled 默认为 false")
    func renderResponseBackwardCompatibility() throws {
        let json = """
        {"success":true,"message":"Loaded preview"}
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode(RenderResponse.self, from: data)

        #expect(decoded.success == true)
        #expect(decoded.livePreviewEnabled == false)
        #expect(decoded.liveWindowNumber == nil)
    }

    // MARK: - LiveFrameRequest

    @Test("LiveFrameRequest 可编码和解码")
    func liveFrameRequestCoding() throws {
        let frame = LiveFrameRequest(x: 100.0, y: 200.0, width: 320.0, height: 180.0)
        let data = try JSONEncoder().encode(frame)
        let decoded = try JSONDecoder().decode(LiveFrameRequest.self, from: data)

        #expect(decoded.x == 100.0)
        #expect(decoded.y == 200.0)
        #expect(decoded.width == 320.0)
        #expect(decoded.height == 180.0)
    }

    @Test("RenderRequest 携带 liveFrame")
    func renderRequestWithLiveFrame() throws {
        let frame = LiveFrameRequest(x: 50, y: 100, width: 640, height: 480)
        let request = RenderRequest(
            command: .updateLiveFrame,
            liveFrame: frame
        )

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(RenderRequest.self, from: data)

        #expect(decoded.command == .updateLiveFrame)
        #expect(decoded.liveFrame?.x == 50)
        #expect(decoded.liveFrame?.y == 100)
        #expect(decoded.liveFrame?.width == 640)
        #expect(decoded.liveFrame?.height == 480)
    }

    // MARK: - PreviewHostCommand Live Commands

    @Test("PreviewHostCommand 包含所有 Live 命令")
    func hostCommandIncludesLiveCommands() {
        let liveCommands: [PreviewHostCommand] = [
            .startLivePreview,
            .updateLiveFrame,
            .showLivePreview,
            .hideLivePreview,
            .reloadLivePreview,
            .stopLivePreview
        ]

        for command in liveCommands {
            let rawValue = command.rawValue
            let reconstructed = PreviewHostCommand(rawValue: rawValue)
            #expect(reconstructed == command)
        }
    }

    // MARK: - Integration: Live preview lifecycle through host process

    @Test("完整的 loadDylib → startLive → show → hide → stop 管线")
    func livePreviewLifecycle() async throws {
        let executableURL = try buildHostExecutable()
        let connection = try await PreviewHostProcess().launch(executableURL: executableURL)
        defer {
            Task { await connection.terminate() }
        }

        // 先加载一个带 NSView 的 dylib
        let dylibURL = try await buildSignedDylib(
            source: #"""
            import AppKit
            import Darwin
            import SwiftUI

            @_cdecl("lumi_preview_entry")
            public func lumiPreviewEntry() -> UnsafePointer<CChar>? {
                let json = #"{"title":"Lifecycle Test","subtitle":"NSHostingView"}"#
                return strdup(json).map { UnsafePointer($0) }
            }

            @_cdecl("lumi_preview_make_nsview")
            public func lumiPreviewMakeNSView() -> UnsafeMutableRawPointer? {
                let view = NSHostingView(rootView: AnyView(Text("Live Preview").padding()))
                view.frame = NSRect(x: 0, y: 0, width: 320, height: 180)
                return Unmanaged.passRetained(view).toOpaque()
            }
            """#
        )

        let loadResponse = try await connection.requestLoadPreviewEntry(
            at: dylibURL,
            symbolName: PreviewEntryBuilder.symbolName
        )
        #expect(loadResponse.success)
        #expect(loadResponse.livePreviewEnabled == true)

        // startLivePreview
        let startResponse = try await connection.requestStartLivePreview()
        #expect(startResponse.success)
        #expect(startResponse.livePreviewEnabled == true)
        #expect(startResponse.liveWindowNumber != nil)

        // updateLiveFrame
        let frameResponse = try await connection.requestUpdateLiveFrame(
            x: 100, y: 200, width: 400, height: 300
        )
        #expect(frameResponse.success)

        // showLivePreview
        let showResponse = try await connection.requestShowLivePreview()
        #expect(showResponse.success)

        // hideLivePreview
        let hideResponse = try await connection.requestHideLivePreview()
        #expect(hideResponse.success)

        // stopLivePreview
        let stopResponse = try await connection.requestStopLivePreview()
        #expect(stopResponse.success)

        await connection.terminate()
    }

    @Test("未加载 NSView entry 时 startLivePreview 返回失败")
    func startLivePreviewFailsWithoutNSViewEntry() async throws {
        let executableURL = try buildHostExecutable()
        let connection = try await PreviewHostProcess().launch(executableURL: executableURL)
        defer {
            Task { await connection.terminate() }
        }

        // 只加载 descriptor entry（不包含 NSView）
        let dylibURL = try await buildSignedDylib(
            source: #"""
            import Darwin

            @_cdecl("lumi_preview_entry")
            public func lumiPreviewEntry() -> UnsafePointer<CChar>? {
                let json = #"{"title":"Descriptor Only"}"#
                return strdup(json).map { UnsafePointer($0) }
            }
            """#
        )

        _ = try await connection.requestLoadPreviewEntry(
            at: dylibURL,
            symbolName: PreviewEntryBuilder.symbolName
        )

        // startLivePreview 应该失败
        do {
            _ = try await connection.requestStartLivePreview()
            Issue.record("Expected startLivePreview to fail without NSView entry")
        } catch {
            // 预期失败
        }

        await connection.terminate()
    }

    @Test("reloadLivePreview 加载新 dylib 替换 root view")
    func reloadLivePreviewReplacesRootView() async throws {
        let executableURL = try buildHostExecutable()
        let connection = try await PreviewHostProcess().launch(executableURL: executableURL)
        defer {
            Task { await connection.terminate() }
        }

        // 初始加载
        let initialDylibURL = try await buildSignedDylib(
            source: #"""
            import AppKit
            import Darwin
            import SwiftUI

            @_cdecl("lumi_preview_entry")
            public func lumiPreviewEntry() -> UnsafePointer<CChar>? {
                let json = #"{"title":"Initial View"}"#
                return strdup(json).map { UnsafePointer($0) }
            }

            @_cdecl("lumi_preview_make_nsview")
            public func lumiPreviewMakeNSView() -> UnsafeMutableRawPointer? {
                let view = NSHostingView(rootView: AnyView(Text("Initial").padding()))
                view.frame = NSRect(x: 0, y: 0, width: 320, height: 180)
                return Unmanaged.passRetained(view).toOpaque()
            }
            """#
        )

        let initialResponse = try await connection.requestLoadPreviewEntry(
            at: initialDylibURL,
            symbolName: PreviewEntryBuilder.symbolName
        )
        #expect(initialResponse.livePreviewEnabled == true)

        // 启动 live
        let startResponse = try await connection.requestStartLivePreview()
        #expect(startResponse.success)

        // reload
        let updatedDylibURL = try await buildSignedDylib(
            source: #"""
            import AppKit
            import Darwin
            import SwiftUI

            @_cdecl("lumi_preview_entry")
            public func lumiPreviewEntry() -> UnsafePointer<CChar>? {
                let json = #"{"title":"Updated View"}"#
                return strdup(json).map { UnsafePointer($0) }
            }

            @_cdecl("lumi_preview_make_nsview")
            public func lumiPreviewMakeNSView() -> UnsafeMutableRawPointer? {
                let view = NSHostingView(rootView: AnyView(Text("Updated").padding()))
                view.frame = NSRect(x: 0, y: 0, width: 320, height: 180)
                return Unmanaged.passRetained(view).toOpaque()
            }
            """#
        )

        let reloadResponse = try await connection.requestReloadLivePreview(
            at: updatedDylibURL,
            symbolName: PreviewEntryBuilder.symbolName
        )
        #expect(reloadResponse.success)
        #expect(reloadResponse.livePreviewEnabled == true)
        #expect(reloadResponse.message?.contains("Updated View") == true)

        let showAfterReloadResponse = try await connection.requestShowLivePreview()
        #expect(showAfterReloadResponse.success)
        #expect(showAfterReloadResponse.livePreviewEnabled == true)

        await connection.terminate()
    }

    // MARK: - Helpers

    private func buildHostExecutable() throws -> URL {
        let packageDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let scratchPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewDisplayMode-Host-\(UUID().uuidString)", isDirectory: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "swift", "build",
            "--package-path", packageDirectory.path,
            "--scratch-path", scratchPath.path,
            "--product", "LumiPreviewHostApp"
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw PreviewError.compilationFailed(message: output)
        }

        guard let executableURL = findHostExecutable(in: scratchPath) else {
            throw PreviewError.buildProductNotFound
        }

        return executableURL
    }

    private func findHostExecutable(in scratchPath: URL) -> URL? {
        guard let enumerator = FileManager.default.enumerator(
            at: scratchPath,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for case let url as URL in enumerator where url.lastPathComponent == "LumiPreviewHostApp" {
            if FileManager.default.isExecutableFile(atPath: url.path) {
                return url
            }
        }

        return nil
    }

    private func buildSignedDylib(source: String) async throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiDisplayModeTest-Dylib-\(UUID().uuidString)", isDirectory: true)
        let sourceFile = directory.appendingPathComponent("PreviewPatch.swift")
        let objectFile = directory.appendingPathComponent("PreviewPatch.o")

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try source.write(to: sourceFile, atomically: true, encoding: .utf8)

        let compiler = IncrementalCompiler()
        let compiledObject = try await compiler.compile(
            fileURL: sourceFile,
            compileCommand: "/usr/bin/env swiftc -c '\(sourceFile.path)' -o '\(objectFile.path)'"
        )
        let dylibURL = try await compiler.link(objectFileURL: compiledObject)
        try await compiler.codesign(dylibURL: dylibURL)

        return dylibURL
    }
}

private extension PreviewDisplayModeTests {
    func XCTUnwrap(_ optional: Optional<Data>) throws -> Data {
        guard let value = optional else {
            throw PreviewError.runtimeCrashed(message: "Unexpected nil")
        }
        return value
    }
}
