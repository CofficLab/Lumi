import XCTest
@testable import LumiInlinePreviewKit

private actor BuilderProbe {
    private(set) var entryLoadedSuccess: Bool?
    private(set) var entryLoadedMessage: String?
    private(set) var frameCount: Int = 0

    func recordEntryLoaded(success: Bool, message: String?) {
        entryLoadedSuccess = success
        entryLoadedMessage = message
    }

    func recordFrame() {
        frameCount += 1
    }
}

/// 端到端验证 `InlinePreviewBuilder` + 子进程 dlopen 路径：
///
/// 1. 写一段含 `#Preview { Text("hello") }` 的源到临时文件。
/// 2. `InlinePreviewBuilder.build` 编译为 dylib。
/// 3. `ProcessInlineHostConnection` spawn 子进程；`startFrameStream`；`loadDylib`。
/// 4. 收到 `entryLoaded(success: true)` + 至少一帧。
/// 5. 复用同一份 source 再 build 一次，验证缓存命中（`usedCache == true`）。
final class InlinePreviewBuilderTests: XCTestCase {

    private static let userSource = """
    import SwiftUI

    struct DemoEntryView: View {
        var body: some View {
            Text("inline preview entry")
        }
    }

    #Preview {
        DemoEntryView()
    }
    """

    func test_build_thenLoadDylib_endToEnd() async throws {
        guard let hostURL = LumiInlinePreviewFacade.InlineHostExecutableResolver.resolve() else {
            throw XCTSkip("LumiInlinePreviewHostApp binary not found; run `swift build` first.")
        }

        let workspace = makeTempWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }

        let userFileURL = workspace.appendingPathComponent("DemoEntryView.swift")
        try Self.userSource.write(to: userFileURL, atomically: true, encoding: .utf8)

        let builder = LumiInlinePreviewFacade.InlinePreviewBuilder(
            workspaceRoot: workspace.appendingPathComponent("build", isDirectory: true)
        )

        let firstResult: LumiInlinePreviewFacade.InlinePreviewBuilder.BuildResult
        do {
            firstResult = try await builder.build(fileURL: userFileURL, sourceText: Self.userSource)
        } catch let LumiInlinePreviewFacade.InlinePreviewBuilder.BuildError.swiftcFailed(stderr) {
            throw XCTSkip("swiftc failed (likely toolchain issue):\n\(stderr)")
        } catch let LumiInlinePreviewFacade.InlinePreviewBuilder.BuildError.sdkResolutionFailed(message) {
            throw XCTSkip("SDK unavailable: \(message)")
        }
        XCTAssertFalse(firstResult.usedCache)
        XCTAssertEqual(firstResult.primaryTitle, "Preview 1")
        XCTAssertTrue(FileManager.default.fileExists(atPath: firstResult.dylibURL.path),
                      "dylib should exist on disk: \(firstResult.dylibURL.path)")

        // 再 build 一次应直接命中缓存。
        let cachedResult = try await builder.build(fileURL: userFileURL, sourceText: Self.userSource)
        XCTAssertTrue(cachedResult.usedCache, "second build with identical source should hit cache")
        XCTAssertEqual(cachedResult.dylibURL, firstResult.dylibURL)

        // 让子进程加载 dylib 并验证产帧。
        let connection = try LumiInlinePreviewFacade.ProcessInlineHostConnection.launch(executableURL: hostURL)

        let probe = BuilderProbe()
        let loadedExpectation = expectation(description: "entryLoaded(success: true) received")
        let frameExpectation = expectation(description: "frame received after dylib load")
        var pendingLoaded: XCTestExpectation? = loadedExpectation
        var pendingFrame: XCTestExpectation? = frameExpectation

        let events = connection.events
        let eventTask = Task {
            for await event in events {
                switch event {
                case .entryLoaded(let success, let message):
                    await probe.recordEntryLoaded(success: success, message: message)
                    if success, message == nil, let exp = pendingLoaded {
                        pendingLoaded = nil
                        exp.fulfill()
                    }
                case .frameProduced:
                    await probe.recordFrame()
                    let count = await probe.frameCount
                    if count >= 1, let exp = pendingFrame {
                        pendingFrame = nil
                        exp.fulfill()
                    }
                case .streamStateChanged, .error:
                    break
                }
            }
        }

        let startResp = try await connection.send(.startFrameStream(width: 320, height: 180, scale: 2))
        XCTAssertTrue(startResp.success)

        let loadResp = try await connection.send(
            .loadDylib(path: firstResult.dylibURL.path, symbolName: "lumi_preview_make_nsview")
        )
        XCTAssertTrue(loadResp.success, "loadDylib failed: \(loadResp.message ?? "nil")")

        await fulfillment(of: [loadedExpectation, frameExpectation], timeout: 5)

        eventTask.cancel()
        await connection.terminate()
    }

    func test_build_throwsNoPreviewFound_whenSourceHasNoPreview() async throws {
        let workspace = makeTempWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }

        let userFileURL = workspace.appendingPathComponent("NoPreview.swift")
        let source = "import Foundation\nlet x = 1\n"
        try source.write(to: userFileURL, atomically: true, encoding: .utf8)

        let builder = LumiInlinePreviewFacade.InlinePreviewBuilder(
            workspaceRoot: workspace.appendingPathComponent("build", isDirectory: true)
        )

        do {
            _ = try await builder.build(fileURL: userFileURL, sourceText: source)
            XCTFail("expected BuildError.noPreviewFound")
        } catch LumiInlinePreviewFacade.InlinePreviewBuilder.BuildError.noPreviewFound {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - Helpers

    private func makeTempWorkspace() -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("InlinePreviewBuilderTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
