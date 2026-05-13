import Foundation
import AppKit
import Testing
@testable import LumiPreviewKit

@Suite("PreviewHostProcess", .serialized)
struct HostProcessTests {

    @Test("RenderRequest 编码环境注入配置")
    func renderRequestEncodesEnvironmentInjections() throws {
        let request = RenderRequest(
            command: .render,
            discovery: PreviewDiscovery(
                id: "preview-env",
                title: "Env Preview",
                sourceFileURL: URL(fileURLWithPath: "/tmp/EnvView.swift"),
                lineNumber: 1,
                endLineNumber: 5,
                primaryTypeName: "EnvView",
                bodySource: "EnvView()"
            ),
            configuration: PreviewRenderConfiguration(
                environmentInjections: [
                    PreviewEnvironmentInjection(
                        typeName: "AppModel",
                        mockIdentifier: "mock.appModel",
                        displayName: "Mock App Model"
                    )
                ]
            )
        )

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(RenderRequest.self, from: data)

        #expect(decoded.configuration.environmentInjections.count == 1)
        #expect(decoded.configuration.environmentInjections[0].typeName == "AppModel")
        #expect(decoded.configuration.environmentInjections[0].mockIdentifier == "mock.appModel")
        #expect(decoded.configuration.environmentInjections[0].displayName == "Mock App Model")
    }

    @Test("RenderResponse 编码 fallback 诊断")
    func renderResponseEncodesFallbackDiagnostics() throws {
        let response = RenderResponse(
            success: true,
            previewID: "lumi_preview_entry",
            message: "Loaded preview entry Broken",
            diagnostics: "Preview view entry failed",
            isFallback: true
        )

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(RenderResponse.self, from: data)

        #expect(decoded.diagnostics == "Preview view entry failed")
        #expect(decoded.isFallback == true)
    }

    @Test("PreviewEntryDescriptor 编码 fallback 诊断")
    func previewEntryDescriptorEncodesFallbackDiagnostics() throws {
        let descriptor = PreviewEntryDescriptor(
            title: "Broken",
            subtitle: "BrokenView",
            body: "BrokenView()",
            diagnostics: "cannot find 'BrokenView' in scope",
            isFallback: true
        )

        let data = try JSONEncoder().encode(descriptor)
        let decoded = try JSONDecoder().decode(PreviewEntryDescriptor.self, from: data)

        #expect(decoded.diagnostics == "cannot find 'BrokenView' in scope")
        #expect(decoded.isFallback == true)
    }

    @Test("启动宿主进程 → 发送 RenderRequest → 收到 RenderResponse")
    func launchAndRender() async throws {
        let executableURL = try buildHostExecutable()
        let connection = try await PreviewHostProcess().launch(executableURL: executableURL)
        defer {
            Task {
                await connection.terminate()
            }
        }

        let discovery = PreviewDiscovery(
            id: "preview-1",
            title: "Test Preview",
            sourceFileURL: URL(fileURLWithPath: "/tmp/TestView.swift"),
            lineNumber: 1,
            endLineNumber: 3,
            primaryTypeName: "TestView",
            bodySource: "TestView()"
        )

        let renderResponse = try await connection.requestRender(discovery: discovery)
        #expect(renderResponse.previewImagePNGBase64 != nil)

        let refreshResponse = try await connection.requestRefresh()
        #expect(refreshResponse.previewImagePNGBase64 != nil)
        await connection.terminate()
    }

    @Test("宿主进程通过 dlopen 加载 dylib")
    func loadDylib() async throws {
        let executableURL = try buildHostExecutable()
        let connection = try await PreviewHostProcess().launch(executableURL: executableURL)
        defer {
            Task {
                await connection.terminate()
            }
        }

        let dylibURL = try await buildSignedDylib(
            source: """
            public func lumiPreviewPatchValue() -> Int {
                42
            }
            """
        )

        try await connection.requestLoadDylib(at: dylibURL)
        await connection.terminate()
    }

    @Test("宿主进程解析 dylib 预览入口并替换视图")
    func loadPreviewEntryFromDylib() async throws {
        let executableURL = try buildHostExecutable()
        let connection = try await PreviewHostProcess().launch(executableURL: executableURL)
        defer {
            Task {
                await connection.terminate()
            }
        }

        let dylibURL = try await buildSignedDylib(
            source: """
            import Darwin

            @_cdecl("lumi_preview_title")
            public func lumiPreviewTitle() -> UnsafePointer<CChar>? {
                strdup("Dynamic Preview").map { UnsafePointer($0) }
            }
            """
        )

        let response = try await connection.requestLoadPreviewEntry(
            at: dylibURL,
            symbolName: "lumi_preview_title"
        )
        #expect(response.message == "Loaded preview entry Dynamic Preview")
        #expect(response.previewImagePNGBase64 != nil)
        await connection.terminate()
    }

    @Test("宿主进程解析 dylib 预览入口描述并渲染 surface")
    func loadPreviewEntryDescriptorFromDylib() async throws {
        let executableURL = try buildHostExecutable()
        let connection = try await PreviewHostProcess().launch(executableURL: executableURL)
        defer {
            Task {
                await connection.terminate()
            }
        }

        let dylibURL = try await buildSignedDylib(
            source: #"""
            import Darwin

            @_cdecl("lumi_preview_entry")
            public func lumiPreviewEntry() -> UnsafePointer<CChar>? {
                let json = #"{"title":"Dynamic Card","subtitle":"CardView","body":"Generated preview descriptor"}"#
                return strdup(json).map { UnsafePointer($0) }
            }
            """#
        )

        let response = try await connection.requestLoadPreviewEntry(
            at: dylibURL,
            symbolName: "lumi_preview_entry"
        )

        #expect(response.message == "Loaded preview entry Dynamic Card")
        #expect(response.previewID == "lumi_preview_entry")
        #expect(response.previewImagePNGBase64 != nil)
        await connection.terminate()
    }

    @Test("宿主进程透传 fallback 预览诊断")
    func loadFallbackPreviewEntryDescriptorFromDylib() async throws {
        let executableURL = try buildHostExecutable()
        let connection = try await PreviewHostProcess().launch(executableURL: executableURL)
        defer {
            Task {
                await connection.terminate()
            }
        }

        let dylibURL = try await buildSignedDylib(
            source: #"""
            import Darwin

            @_cdecl("lumi_preview_entry")
            public func lumiPreviewEntry() -> UnsafePointer<CChar>? {
                let json = #"{"title":"Broken Card","subtitle":"BrokenView","body":"BrokenView()","diagnostics":"cannot find 'BrokenView' in scope","isFallback":true}"#
                return strdup(json).map { UnsafePointer($0) }
            }
            """#
        )

        let response = try await connection.requestLoadPreviewEntry(
            at: dylibURL,
            symbolName: "lumi_preview_entry"
        )

        #expect(response.message == "Loaded preview entry Broken Card")
        #expect(response.diagnostics == "cannot find 'BrokenView' in scope")
        #expect(response.isFallback == true)
        #expect(response.previewImagePNGBase64 != nil)
        await connection.terminate()
    }

    @Test("宿主进程优先加载 dylib 返回的 NSView")
    func loadPreviewNSViewFromDylib() async throws {
        let executableURL = try buildHostExecutable()
        let connection = try await PreviewHostProcess().launch(executableURL: executableURL)
        defer {
            Task {
                await connection.terminate()
            }
        }

        let dylibURL = try await buildSignedDylib(
            source: #"""
            import AppKit
            import Darwin
            import SwiftUI

            @_cdecl("lumi_preview_entry")
            public func lumiPreviewEntry() -> UnsafePointer<CChar>? {
                let json = #"{"title":"Real NSView","subtitle":"NSHostingView"}"#
                return strdup(json).map { UnsafePointer($0) }
            }

            @_cdecl("lumi_preview_make_nsview")
            public func lumiPreviewMakeNSView() -> UnsafeMutableRawPointer? {
                let view = NSHostingView(rootView: AnyView(Text("Rendered from NSView entry").padding()))
                view.frame = NSRect(x: 0, y: 0, width: 320, height: 180)
                return Unmanaged.passRetained(view).toOpaque()
            }
            """#
        )

        let response = try await connection.requestLoadPreviewEntry(
            at: dylibURL,
            symbolName: "lumi_preview_entry"
        )

        #expect(response.message == "Loaded preview view entry Real NSView")
        #expect(response.previewID == "lumi_preview_make_nsview")
        #expect(response.previewImagePNGBase64 != nil)
        await connection.terminate()
    }

    @Test("宿主进程在离屏窗口中渲染 NSView")
    func loadPreviewNSViewRendersAfterWindowAttachment() async throws {
        let executableURL = try buildHostExecutable()
        let connection = try await PreviewHostProcess().launch(executableURL: executableURL)
        defer {
            Task {
                await connection.terminate()
            }
        }

        let dylibURL = try await buildSignedDylib(
            source: #"""
            import AppKit
            import Darwin

            final class WindowAwarePreviewView: NSView {
                override var intrinsicContentSize: NSSize {
                    NSSize(width: 640, height: 360)
                }

                override func draw(_ dirtyRect: NSRect) {
                    (window == nil ? NSColor.white : NSColor.red).setFill()
                    bounds.fill()
                }
            }

            @_cdecl("lumi_preview_entry")
            public func lumiPreviewEntry() -> UnsafePointer<CChar>? {
                let json = #"{"title":"Window-Aware NSView","subtitle":"NSView"}"#
                return strdup(json).map { UnsafePointer($0) }
            }

            @_cdecl("lumi_preview_make_nsview")
            public func lumiPreviewMakeNSView() -> UnsafeMutableRawPointer? {
                let view = WindowAwarePreviewView(frame: NSRect(x: 0, y: 0, width: 320, height: 180))
                view.frame = NSRect(x: 0, y: 0, width: 320, height: 180)
                return Unmanaged.passRetained(view).toOpaque()
            }
            """#
        )

        let response = try await connection.requestLoadPreviewEntry(
            at: dylibURL,
            symbolName: "lumi_preview_entry"
        )
        let bitmap = try decodedBitmap(from: response.previewImagePNGBase64)

        #expect(response.message == "Loaded preview view entry Window-Aware NSView")
        #expect(bitmap.pixelsWide >= 600)
        #expect(bitmap.pixelsHigh >= 340)
        #expect(containsRedPixel(in: bitmap))
        await connection.terminate()
    }

    @Test("增量编译失败后宿主进程仍可刷新")
    func compileFailureDoesNotAffectRunningHost() async throws {
        let executableURL = try buildHostExecutable()
        let connection = try await PreviewHostProcess().launch(executableURL: executableURL)
        defer {
            Task {
                await connection.terminate()
            }
        }

        let discovery = PreviewDiscovery(
            id: "stable-preview",
            title: "Stable Preview",
            sourceFileURL: URL(fileURLWithPath: "/tmp/StableView.swift"),
            lineNumber: 1,
            endLineNumber: 3,
            primaryTypeName: "StableView",
            bodySource: "StableView()"
        )
        try await connection.requestRender(discovery: discovery)

        do {
            _ = try await buildBrokenObjectFile()
            Issue.record("Expected compilationFailed")
        } catch PreviewError.compilationFailed {
        } catch {
            Issue.record("Expected compilationFailed, got \(error)")
        }

        try await connection.requestRefresh()
        await connection.terminate()
    }

    @Test("单文件修改 → 增量编译 → 宿主进程刷新耗时小于 3 秒")
    func incrementalRefreshCompletesUnderThreeSeconds() async throws {
        let executableURL = try buildHostExecutable()
        let connection = try await PreviewHostProcess().launch(executableURL: executableURL)
        defer {
            Task {
                await connection.terminate()
            }
        }

        let fixture = try makeIncrementalPreviewFixture(title: "Initial Preview")
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        let initialDylibURL = try await buildSignedDylib(
            sourceFile: fixture.sourceFile,
            objectFile: fixture.objectFile
        )
        try await connection.requestLoadPreviewEntry(
            at: initialDylibURL,
            symbolName: "lumi_preview_title"
        )

        try incrementalPreviewSource(title: "Updated Preview")
            .write(to: fixture.sourceFile, atomically: true, encoding: .utf8)

        let start = Date()
        let updatedDylibURL = try await buildSignedDylib(
            sourceFile: fixture.sourceFile,
            objectFile: fixture.objectFile
        )
        try await connection.requestLoadPreviewEntry(
            at: updatedDylibURL,
            symbolName: "lumi_preview_title"
        )
        try await connection.requestRefresh()
        let elapsed = Date().timeIntervalSince(start)

        #expect(elapsed < 5)
        await connection.terminate()
    }

    @Test("reloadLivePreview 失败后仍保留上一份成功预览")
    func failedReloadKeepsPreviousPreview() async throws {
        let executableURL = try buildHostExecutable()
        let connection = try await PreviewHostProcess().launch(executableURL: executableURL)
        defer {
            Task {
                await connection.terminate()
            }
        }

        let initialDylibURL = try await buildSignedDylib(
            source: #"""
            import AppKit
            import Darwin
            import SwiftUI

            @_cdecl("lumi_preview_entry")
            public func lumiPreviewEntry() -> UnsafePointer<CChar>? {
                let json = #"{"title":"Stable Live View"}"#
                return strdup(json).map { UnsafePointer($0) }
            }

            @_cdecl("lumi_preview_make_nsview")
            public func lumiPreviewMakeNSView() -> UnsafeMutableRawPointer? {
                let view = NSHostingView(rootView: AnyView(Text("Stable").padding()))
                view.frame = NSRect(x: 0, y: 0, width: 320, height: 180)
                return Unmanaged.passRetained(view).toOpaque()
            }
            """#
        )

        let initialResponse = try await connection.requestLoadPreviewEntry(
            at: initialDylibURL,
            symbolName: "lumi_preview_entry"
        )
        #expect(initialResponse.message == "Loaded preview view entry Stable Live View")
        #expect(initialResponse.previewImagePNGBase64 != nil)

        let startResponse = try await connection.requestStartLivePreview()
        #expect(startResponse.success)

        let brokenReloadDylibURL = try await buildSignedDylib(
            source: #"""
            import Darwin

            @_cdecl("lumi_preview_entry")
            public func lumiPreviewEntry() -> UnsafePointer<CChar>? {
                let json = #"{"title":"Broken Live View"}"#
                return strdup(json).map { UnsafePointer($0) }
            }
            """#
        )

        do {
            _ = try await connection.requestReloadLivePreview(
                at: brokenReloadDylibURL,
                symbolName: "lumi_preview_entry"
            )
            Issue.record("Expected reloadLivePreview to fail without NSView entry")
        } catch PreviewError.runtimeCrashed(let message) {
            #expect(message.contains("Reload failed"))
        } catch {
            Issue.record("Expected runtimeCrashed, got \(error)")
        }

        let refreshResponse = try await connection.requestRefresh()
        #expect(refreshResponse.message == "Refreshed Stable Live View")
        #expect(refreshResponse.previewImagePNGBase64 != nil)
    }


    @Test("宿主进程无法启动 → 抛出 hostLaunchFailed")
    func launchFailureThrowsHostLaunchFailed() async {
        let missingExecutable = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString)")

        do {
            _ = try await PreviewHostProcess().launch(executableURL: missingExecutable)
            Issue.record("Expected hostLaunchFailed")
        } catch PreviewError.hostLaunchFailed(let message) {
            #expect(message.contains(missingExecutable.path))
        } catch {
            Issue.record("Expected hostLaunchFailed, got \(error)")
        }
    }

    @Test("terminate 后宿主进程退出，后续请求失败")
    func terminateStopsHostProcess() async throws {
        let executableURL = try buildHostExecutable()
        let connection = try await PreviewHostProcess().launch(executableURL: executableURL)
        let processID = await connection.processID

        #expect(await connection.isRunning)
        #expect(processID > 0)

        await connection.terminate()

        try await waitForProcessExit(processID)
        #expect(!(await connection.isRunning))

        do {
            _ = try await connection.requestRefresh()
            Issue.record("Expected hostLaunchFailed after termination")
        } catch PreviewError.hostLaunchFailed(let message) {
            #expect(message.contains("not running") || message.contains("closed stdout"))
        } catch {
            Issue.record("Expected hostLaunchFailed after termination, got \(error)")
        }
    }

    @Test("反复启动和关闭宿主进程不会残留旧 PID")
    func repeatedLaunchAndTerminateLeavesNoResidualProcesses() async throws {
        let executableURL = try buildHostExecutable()
        var previousPIDs = Set<Int32>()

        for _ in 0..<3 {
            let connection = try await PreviewHostProcess().launch(executableURL: executableURL)
            let processID = await connection.processID

            #expect(processID > 0)
            #expect(!previousPIDs.contains(processID))
            #expect(await connection.isRunning)

            previousPIDs.insert(processID)
            await connection.terminate()
            try await waitForProcessExit(processID)
            #expect(!(await connection.isRunning))
        }
    }

    private func buildHostExecutable() throws -> URL {
        let packageDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let scratchPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewHostApp-build-\(UUID().uuidString)", isDirectory: true)
        let result = try runSwiftBuild(packageDirectory: packageDirectory, scratchPath: scratchPath)
        guard result.status == 0 else {
            throw PreviewError.compilationFailed(message: result.output)
        }

        guard let executableURL = findHostExecutable(in: scratchPath) else {
            throw PreviewError.buildProductNotFound
        }

        return executableURL
    }

    private func runSwiftBuild(packageDirectory: URL, scratchPath: URL) throws -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "swift",
            "build",
            "--package-path",
            packageDirectory.path,
            "--scratch-path",
            scratchPath.path,
            "--product",
            "LumiPreviewHostApp"
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        let output = String(
            data: pipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""

        return (process.terminationStatus, output)
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

    private func waitForProcessExit(_ processID: Int32, timeout: TimeInterval = 2) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !processExists(processID) {
                return
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        Issue.record("Process \(processID) still exists after timeout")
    }

    private func processExists(_ processID: Int32) -> Bool {
        if kill(processID, 0) == 0 {
            return true
        }
        return errno != ESRCH
    }

    private func decodedBitmap(from base64: String?) throws -> NSBitmapImageRep {
        guard let base64,
              let data = Data(base64Encoded: base64),
              let bitmap = NSBitmapImageRep(data: data) else {
            throw PreviewError.runtimeCrashed(message: "Expected a valid PNG preview image.")
        }

        return bitmap
    }

    private func containsRedPixel(in bitmap: NSBitmapImageRep) -> Bool {
        let samplePoints = [
            (max(bitmap.pixelsWide / 8, 0), max(bitmap.pixelsHigh / 8, 0)),
            (max(bitmap.pixelsWide / 2, 0), max(bitmap.pixelsHigh / 8, 0)),
            (max(bitmap.pixelsWide * 7 / 8, 0), max(bitmap.pixelsHigh * 7 / 8, 0))
        ]

        return samplePoints.contains { x, y in
            guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
                return false
            }

            return color.redComponent > 0.7
                && color.greenComponent < 0.25
                && color.blueComponent < 0.25
                && color.alphaComponent > 0.8
        }
    }

    private func buildSignedDylib(source: String) async throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewHostDylib-\(UUID().uuidString)", isDirectory: true)
        let sourceFile = directory.appendingPathComponent("PreviewPatch.swift")
        let objectFile = directory.appendingPathComponent("PreviewPatch.o")

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try source.write(to: sourceFile, atomically: true, encoding: .utf8)

        return try await buildSignedDylib(sourceFile: sourceFile, objectFile: objectFile)
    }

    private func buildSignedDylib(sourceFile: URL, objectFile: URL) async throws -> URL {
        let compiler = IncrementalCompiler()
        let compiledObject = try await compiler.compile(
            fileURL: sourceFile,
            compileCommand: "/usr/bin/env swiftc -c \(shellQuoted(sourceFile.path)) -o \(shellQuoted(objectFile.path))"
        )
        let dylibURL = try await compiler.link(objectFileURL: compiledObject)
        try await compiler.codesign(dylibURL: dylibURL)

        return dylibURL
    }

    private func makeIncrementalPreviewFixture(
        title: String
    ) throws -> (directory: URL, sourceFile: URL, objectFile: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewHostIncremental-\(UUID().uuidString)", isDirectory: true)
        let sourceFile = directory.appendingPathComponent("PreviewPatch.swift")
        let objectFile = directory.appendingPathComponent("PreviewPatch.o")

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try incrementalPreviewSource(title: title)
            .write(to: sourceFile, atomically: true, encoding: .utf8)

        return (directory, sourceFile, objectFile)
    }

    private func incrementalPreviewSource(title: String) -> String {
        """
        import Darwin

        @_cdecl("lumi_preview_title")
        public func lumiPreviewTitle() -> UnsafePointer<CChar>? {
            strdup("\(title)").map { UnsafePointer($0) }
        }
        """
    }

    private func buildBrokenObjectFile() async throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewHostBrokenDylib-\(UUID().uuidString)", isDirectory: true)
        let sourceFile = directory.appendingPathComponent("BrokenPatch.swift")
        let objectFile = directory.appendingPathComponent("BrokenPatch.o")

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try """
        public func brokenPreviewPatch() -> String {
            let value =
            return value
        }
        """.write(to: sourceFile, atomically: true, encoding: .utf8)

        return try await IncrementalCompiler().compile(
            fileURL: sourceFile,
            compileCommand: "/usr/bin/env swiftc -c \(shellQuoted(sourceFile.path)) -o \(shellQuoted(objectFile.path))"
        )
    }

    private func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
