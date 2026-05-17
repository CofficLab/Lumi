import Foundation
import Testing
import LumiPreviewKit
@testable import LumiPreviewKit

@Suite("HotPreviewHostProcess", .serialized)
struct HotPreviewHostProcessTests {
    private enum TestError: Error {
        case missingPreviewFrameBytes
    }

    @Test("launches hot host and interposes a live preview dylib")
    func interposesLivePreviewDylib() async throws {
        let executableURL = try buildHotHostExecutable()
        let connection = try await LumiPreviewFacade.HotPreviewHostProcess().launch(executableURL: executableURL)
        defer {
            Task {
                await connection.terminate()
            }
        }

        let initialDylibURL = try await buildPreviewDylib(
            title: "Initial Preview",
            text: "Initial",
            red: 0.90,
            green: 0.20,
            blue: 0.20
        )
        let interposedDylibURL = try await buildPreviewDylib(
            title: "Interposed Preview",
            text: "Interposed",
            red: 0.15,
            green: 0.35,
            blue: 0.95
        )

        let loadResponse = try await connection.requestLoadPreviewEntry(
            at: initialDylibURL,
            symbolName: LumiPreviewFacade.PreviewEntryBuilder.symbolName
        )
        #expect(loadResponse.success)
        #expect(loadResponse.imageFilePath == nil)
        #expect(loadResponse.previewImagePNGBase64 != nil)
        #expect(loadResponse.sharedMemoryTag != nil)
        #expect(loadResponse.frameWidth != nil)
        #expect(loadResponse.frameHeight != nil)
        #expect(loadResponse.bytesPerRow != nil)
        #expect(loadResponse.livePreviewEnabled)
        let initialFrame = try frameBytes(from: loadResponse)

        let startResponse = try await connection.requestStartLivePreview()
        #expect(startResponse.success)
        #expect(startResponse.liveWindowNumber != nil)

        let interposeResponse = try await connection.requestInterposeDylib(
            at: interposedDylibURL,
            symbolName: LumiPreviewFacade.PreviewEntryBuilder.symbolName
        )
        #expect(interposeResponse.success)
        #expect(interposeResponse.imageFilePath == nil)
        #expect(interposeResponse.previewImagePNGBase64 != nil)
        #expect(interposeResponse.sharedMemoryTag != nil)
        #expect(interposeResponse.livePreviewEnabled)
        #expect(interposeResponse.liveWindowNumber == startResponse.liveWindowNumber)
        let interposedFrame = try frameBytes(from: interposeResponse)
        #expect(interposedFrame != initialFrame)

        let captureResponse = try await connection.requestCaptureFrame()
        #expect(captureResponse.success)
        #expect(captureResponse.imageFilePath == nil)
        #expect(captureResponse.previewImagePNGBase64 != nil)
        #expect(captureResponse.sharedMemoryTag != nil)
        #expect(captureResponse.liveWindowNumber == startResponse.liveWindowNumber)
        let capturedFrame = try frameBytes(from: captureResponse)
        #expect(capturedFrame == interposedFrame)
        #expect(capturedFrame != initialFrame)

        let hideResponse = try await connection.requestHideLivePreview()
        #expect(hideResponse.success)
        #expect(hideResponse.liveWindowNumber == startResponse.liveWindowNumber)

        let showResponse = try await connection.requestShowLivePreview()
        #expect(showResponse.success)
        #expect(showResponse.liveWindowNumber == startResponse.liveWindowNumber)
    }


    @Test("refresh keeps live session without reloading dylib path")
    func refreshAfterLoad() async throws {
        let executableURL = try buildHotHostExecutable()
        let connection = try await LumiPreviewFacade.HotPreviewHostProcess().launch(executableURL: executableURL)
        defer { Task { await connection.terminate() } }

        let dylibURL = try await buildPreviewDylib(
            title: "Refresh Preview",
            text: "Refresh",
            red: 0.2,
            green: 0.6,
            blue: 0.3
        )

        _ = try await connection.requestLoadPreviewEntry(
            at: dylibURL,
            symbolName: LumiPreviewFacade.PreviewEntryBuilder.symbolName
        )
        let refreshResponse = try await connection.requestRefresh()
        #expect(refreshResponse.success)
    }

    @Test("terminated host can be launched again")
    func relaunchesAfterTermination() async throws {
        let executableURL = try buildHotHostExecutable()
        let connection = try await LumiPreviewFacade.HotPreviewHostProcess().launch(executableURL: executableURL)
        await connection.terminate()
        #expect(await connection.isRunning == false)

        let relaunched = try await LumiPreviewFacade.HotPreviewHostProcess().launch(executableURL: executableURL)
        defer { Task { await relaunched.terminate() } }
        #expect(await relaunched.isRunning)
    }

    private func buildHotHostExecutable() throws -> URL {
        let packageDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let scratchPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiHotPreviewHostApp-build-\(UUID().uuidString)", isDirectory: true)
        let result = try runSwiftBuild(packageDirectory: packageDirectory, scratchPath: scratchPath)
        guard result.status == 0 else {
            throw LumiPreviewFacade.PreviewError.compilationFailed(message: result.output)
        }

        guard let executableURL = findHostExecutable(in: scratchPath) else {
            throw LumiPreviewFacade.PreviewError.buildProductNotFound
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
            "LumiHotPreviewHostApp"
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
            includingPropertiesForKeys: [.isExecutableKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for case let fileURL as URL in enumerator {
            guard fileURL.lastPathComponent == "LumiHotPreviewHostApp" else {
                continue
            }

            let values = try? fileURL.resourceValues(forKeys: [.isExecutableKey, .isRegularFileKey])
            if values?.isExecutable == true && values?.isRegularFile == true {
                return fileURL
            }
        }

        return nil
    }

    private func buildPreviewDylib(
        title: String,
        text: String,
        red: Double,
        green: Double,
        blue: Double
    ) async throws -> URL {
        let source = #"""
        import AppKit
        import Darwin
        import SwiftUI

        @_cdecl("lumi_preview_entry")
        public func lumiPreviewEntry() -> UnsafePointer<CChar>? {
            let json = #"{"title":"\#(title)"}"#
            return strdup(json).map { UnsafePointer($0) }
        }

        @_cdecl("lumi_preview_make_nsview")
        public func lumiPreviewMakeNSView() -> UnsafeMutableRawPointer? {
            let rootView = AnyView(
                ZStack {
                    Color(
                        red: \#(red),
                        green: \#(green),
                        blue: \#(blue)
                    )
                    Text("\#(text)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 320, height: 180)
            )
            let view = NSHostingView(rootView: rootView)
            view.frame = NSRect(x: 0, y: 0, width: 320, height: 180)
            return Unmanaged.passRetained(view).toOpaque()
        }
        """#
        return try await buildSignedDylib(source: source)
    }

    private func buildSignedDylib(source: String) async throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiHotPreviewHostDylib-\(UUID().uuidString)", isDirectory: true)
        let sourceFile = directory.appendingPathComponent("PreviewPatch.swift")
        let objectFile = directory.appendingPathComponent("PreviewPatch.o")

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try source.write(to: sourceFile, atomically: true, encoding: .utf8)

        let compiler = LumiPreviewFacade.IncrementalCompiler()
        let compiledObject = try await compiler.compile(
            fileURL: sourceFile,
            compileCommand: "/usr/bin/env swiftc -c \(shellQuoted(sourceFile.path)) -o \(shellQuoted(objectFile.path))"
        )
        let dylibURL = try await compiler.link(objectFileURL: compiledObject)
        try await compiler.codesign(dylibURL: dylibURL)
        return dylibURL
    }

    private func frameBytes(from response: LumiPreviewFacade.HotRenderResponse) throws -> Data {
        if let tag = response.sharedMemoryTag,
           let width = response.frameWidth,
           let height = response.frameHeight,
           let bytesPerRow = response.bytesPerRow {
            let channel = LumiPreviewFacade.SharedMemoryFrameChannel()
            let mapped = try channel.mapFrame(
                tag: tag,
                width: width,
                height: height,
                bytesPerRow: bytesPerRow
            )
            defer { try? channel.removeFrame(tag: tag) }
            return mapped.withUnsafeBytes { Data($0) }
        }

        if let base64 = response.previewImagePNGBase64,
           let data = Data(base64Encoded: base64) {
            return data
        }

        throw TestError.missingPreviewFrameBytes
    }

    private func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
