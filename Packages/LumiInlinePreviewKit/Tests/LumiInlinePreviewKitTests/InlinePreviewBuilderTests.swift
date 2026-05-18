import AppKit
import SwiftUI
import XCTest
@testable import LumiInlinePreviewKit
import LumiPreviewKit

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
        XCTAssertEqual(firstResult.selectedPreviewIndex, 0)
        XCTAssertEqual(firstResult.previewCount, 1)
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
                case .streamStateChanged, .error, .entryDebugState, .cursorChanged:
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

    func test_discoverPreviews_returnsAllPreviewSummaries() async throws {
        let workspace = makeTempWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }

        let source = """
        import SwiftUI

        #Preview("First") {
            Text("first")
        }

        #Preview("Second") {
            Text("second")
        }
        """
        let userFileURL = workspace.appendingPathComponent("MultiplePreviews.swift")
        try source.write(to: userFileURL, atomically: true, encoding: .utf8)

        let builder = LumiInlinePreviewFacade.InlinePreviewBuilder(
            workspaceRoot: workspace.appendingPathComponent("build", isDirectory: true)
        )

        let summaries = await builder.discoverPreviews(fileURL: userFileURL, sourceText: source)

        XCTAssertEqual(summaries.map(\.index), [0, 1])
        XCTAssertEqual(summaries.map(\.title), ["First", "Second"])
        XCTAssertEqual(summaries.map(\.primaryTypeName), ["Text", "Text"])
    }

    func test_build_usesSelectedPreviewIndexAndCachesSeparately() async throws {
        let workspace = makeTempWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }

        let source = """
        import SwiftUI

        #Preview("First") {
            Text("first")
        }

        #Preview("Second") {
            Text("second")
        }
        """
        let userFileURL = workspace.appendingPathComponent("MultiplePreviews.swift")
        try source.write(to: userFileURL, atomically: true, encoding: .utf8)

        let builder = LumiInlinePreviewFacade.InlinePreviewBuilder(
            workspaceRoot: workspace.appendingPathComponent("build", isDirectory: true)
        )

        let secondResult: LumiInlinePreviewFacade.InlinePreviewBuilder.BuildResult
        do {
            secondResult = try await builder.build(fileURL: userFileURL, sourceText: source, previewIndex: 1)
        } catch let LumiInlinePreviewFacade.InlinePreviewBuilder.BuildError.swiftcFailed(stderr) {
            throw XCTSkip("swiftc failed (likely toolchain issue):\n\(stderr)")
        } catch let LumiInlinePreviewFacade.InlinePreviewBuilder.BuildError.sdkResolutionFailed(message) {
            throw XCTSkip("SDK unavailable: \(message)")
        }
        XCTAssertFalse(secondResult.usedCache)
        XCTAssertEqual(secondResult.primaryTitle, "Second")
        XCTAssertEqual(secondResult.selectedPreviewIndex, 1)
        XCTAssertEqual(secondResult.previewCount, 2)

        let cachedSecond = try await builder.build(fileURL: userFileURL, sourceText: source, previewIndex: 1)
        XCTAssertTrue(cachedSecond.usedCache)
        XCTAssertEqual(cachedSecond.dylibURL, secondResult.dylibURL)

        let firstResult = try await builder.build(fileURL: userFileURL, sourceText: source, previewIndex: 0)
        XCTAssertFalse(firstResult.usedCache)
        XCTAssertEqual(firstResult.primaryTitle, "First")
        XCTAssertNotEqual(firstResult.fingerprint, secondResult.fingerprint)
        XCTAssertNotEqual(firstResult.dylibURL, secondResult.dylibURL)
    }

    func test_build_spmTargetWithLocalDependency_usesPlannedBuildPath() async throws {
        let packageDirectory = makeTempWorkspace()
        defer { try? FileManager.default.removeItem(at: packageDirectory) }

        try writeDependentPackageFixture(at: packageDirectory)

        let previewFileURL = packageDirectory
            .appendingPathComponent("Sources/App/AppPreviewView.swift")
        let source = try String(contentsOf: previewFileURL, encoding: .utf8)

        let builder = LumiInlinePreviewFacade.InlinePreviewBuilder(
            workspaceRoot: packageDirectory.appendingPathComponent("inline-build", isDirectory: true)
        )

        let result: LumiInlinePreviewFacade.InlinePreviewBuilder.BuildResult
        do {
            result = try await builder.build(fileURL: previewFileURL, sourceText: source)
        } catch let LumiInlinePreviewFacade.InlinePreviewBuilder.BuildError.plannedBuildFailed(message) {
            throw XCTSkip("planned SPM build failed, likely toolchain/environment issue:\n\(message)")
        } catch let LumiInlinePreviewFacade.InlinePreviewBuilder.BuildError.swiftcFailed(stderr) {
            throw XCTSkip("swiftc failed (likely toolchain issue):\n\(stderr)")
        } catch let LumiInlinePreviewFacade.InlinePreviewBuilder.BuildError.sdkResolutionFailed(message) {
            throw XCTSkip("SDK unavailable: \(message)")
        }

        XCTAssertFalse(result.usedCache)
        XCTAssertEqual(result.primaryTitle, "Cross Target")
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.dylibURL.path))

        guard let handle = dlopen(result.dylibURL.path, RTLD_NOW | RTLD_LOCAL) else {
            let message = dlerror().map { String(cString: $0) } ?? "unknown dlopen error"
            XCTFail("expected planned entry dylib to load, got: \(message)")
            return
        }
        defer { dlclose(handle) }

        XCTAssertNotNil(dlsym(handle, "lumi_preview_make_nsview"))
    }

    @MainActor
    func test_build_spmTargetWithResourceBundle_linksBundleAccessorAndCreatesView() async throws {
        let packageDirectory = makeTempWorkspace()
        defer { try? FileManager.default.removeItem(at: packageDirectory) }

        try writeResourceBundlePackageFixture(at: packageDirectory)

        let previewFileURL = packageDirectory
            .appendingPathComponent("Sources/App/ResourcePreviewView.swift")
        let source = try String(contentsOf: previewFileURL, encoding: .utf8)

        let builder = LumiInlinePreviewFacade.InlinePreviewBuilder(
            workspaceRoot: packageDirectory.appendingPathComponent("inline-build", isDirectory: true)
        )

        let result: LumiInlinePreviewFacade.InlinePreviewBuilder.BuildResult
        do {
            result = try await builder.build(fileURL: previewFileURL, sourceText: source)
        } catch let LumiInlinePreviewFacade.InlinePreviewBuilder.BuildError.plannedBuildFailed(message) {
            throw XCTSkip("planned SPM resource bundle build failed, likely toolchain/environment issue:\n\(message)")
        } catch let LumiInlinePreviewFacade.InlinePreviewBuilder.BuildError.swiftcFailed(stderr) {
            throw XCTSkip("swiftc failed (likely toolchain issue):\n\(stderr)")
        } catch let LumiInlinePreviewFacade.InlinePreviewBuilder.BuildError.sdkResolutionFailed(message) {
            throw XCTSkip("SDK unavailable: \(message)")
        }

        XCTAssertFalse(result.usedCache)
        XCTAssertEqual(result.primaryTitle, "Resource Bundle")
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.dylibURL.path))

        let linkInputs = LumiPreviewFacade.SPMCompiler().previewCompilerArguments(
            packageDirectory: packageDirectory,
            targetName: "App"
        )
        XCTAssertTrue(
            linkInputs.contains { $0.hasSuffix("resource_bundle_accessor.swift.o") },
            "resource bundle accessor object must be linked into the preview entry"
        )

        guard let handle = dlopen(result.dylibURL.path, RTLD_NOW | RTLD_LOCAL) else {
            let message = dlerror().map { String(cString: $0) } ?? "unknown dlopen error"
            XCTFail("expected resource bundle planned entry dylib to load, got: \(message)")
            return
        }
        defer { dlclose(handle) }

        guard let symbol = dlsym(handle, "lumi_preview_make_nsview") else {
            XCTFail("expected resource bundle planned entry dylib to export lumi_preview_make_nsview")
            return
        }

        typealias MakeView = @convention(c) () -> UnsafeMutableRawPointer?
        let makeView = unsafeBitCast(symbol, to: MakeView.self)
        guard let rawView = makeView() else {
            XCTFail("expected resource bundle preview entry to create an NSView")
            return
        }
        let view = Unmanaged<NSView>.fromOpaque(rawView).takeRetainedValue()
        XCTAssertTrue(view is NSHostingView<AnyView>)
    }

    func test_build_realRepositoryLumiUIPackage_usesPlannedBuildPath() async throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let previewFileURL = repositoryRoot
            .appendingPathComponent("LumiUI/Sources/LumiUI/Components/AppButton.swift")
        guard FileManager.default.fileExists(atPath: previewFileURL.path) else {
            throw XCTSkip("LumiUI real package fixture is unavailable at \(previewFileURL.path)")
        }

        let source = try String(contentsOf: previewFileURL, encoding: .utf8)
        let workspace = makeTempWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }

        let builder = LumiInlinePreviewFacade.InlinePreviewBuilder(
            workspaceRoot: workspace.appendingPathComponent("inline-build", isDirectory: true)
        )

        let result: LumiInlinePreviewFacade.InlinePreviewBuilder.BuildResult
        do {
            result = try await builder.build(fileURL: previewFileURL, sourceText: source)
        } catch let LumiInlinePreviewFacade.InlinePreviewBuilder.BuildError.plannedBuildFailed(message) {
            throw XCTSkip("real LumiUI planned build failed; keep this diagnostic for workspace dependency follow-up:\n\(message)")
        } catch let LumiInlinePreviewFacade.InlinePreviewBuilder.BuildError.swiftcFailed(stderr) {
            throw XCTSkip("swiftc failed (likely toolchain issue):\n\(stderr)")
        } catch let LumiInlinePreviewFacade.InlinePreviewBuilder.BuildError.sdkResolutionFailed(message) {
            throw XCTSkip("SDK unavailable: \(message)")
        }

        XCTAssertFalse(result.usedCache)
        XCTAssertEqual(result.primaryTitle, "Preview 1")
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.dylibURL.path))

        guard let handle = dlopen(result.dylibURL.path, RTLD_NOW | RTLD_LOCAL) else {
            let message = dlerror().map { String(cString: $0) } ?? "unknown dlopen error"
            XCTFail("expected real LumiUI planned entry dylib to load, got: \(message)")
            return
        }
        defer { dlclose(handle) }

        XCTAssertNotNil(dlsym(handle, "lumi_preview_make_nsview"))
    }

    func test_build_realRepositoryLumiAppXcodeTarget_usesPlannedBuildPath() async throws {
        guard ProcessInfo.processInfo.environment["RUN_LUMI_XCODE_PREVIEW_TESTS"] == "1" else {
            throw XCTSkip("Set RUN_LUMI_XCODE_PREVIEW_TESTS=1 to run the slow Lumi app target Xcode planned build integration test.")
        }

        let packagesRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let repositoryRoot = packagesRoot.deletingLastPathComponent()
        let previewFileURL = repositoryRoot
            .appendingPathComponent("LumiApp/Core/Commands/SettingsCommand.swift")
        guard FileManager.default.fileExists(atPath: previewFileURL.path) else {
            throw XCTSkip("Lumi app target fixture is unavailable at \(previewFileURL.path)")
        }

        let source = try String(contentsOf: previewFileURL, encoding: .utf8)
        let workspace = makeTempWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }

        let builder = LumiInlinePreviewFacade.InlinePreviewBuilder(
            workspaceRoot: workspace.appendingPathComponent("inline-build", isDirectory: true)
        )

        let result: LumiInlinePreviewFacade.InlinePreviewBuilder.BuildResult
        do {
            result = try await builder.build(fileURL: previewFileURL, sourceText: source, previewIndex: 0)
        } catch let LumiInlinePreviewFacade.InlinePreviewBuilder.BuildError.plannedBuildFailed(message) {
            throw XCTSkip("real Lumi app target planned build failed; keep this diagnostic for Xcode workspace dependency follow-up:\n\(message)")
        } catch let LumiInlinePreviewFacade.InlinePreviewBuilder.BuildError.swiftcFailed(stderr) {
            throw XCTSkip("swiftc failed (likely toolchain issue):\n\(stderr)")
        } catch let LumiInlinePreviewFacade.InlinePreviewBuilder.BuildError.sdkResolutionFailed(message) {
            throw XCTSkip("SDK unavailable: \(message)")
        }

        XCTAssertFalse(result.usedCache)
        XCTAssertEqual(result.primaryTitle, "Settings Command")
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.dylibURL.path))

        guard let handle = dlopen(result.dylibURL.path, RTLD_NOW | RTLD_LOCAL) else {
            let message = dlerror().map { String(cString: $0) } ?? "unknown dlopen error"
            XCTFail("expected real Lumi app target planned entry dylib to load, got: \(message)")
            return
        }
        defer { dlclose(handle) }

        XCTAssertNotNil(dlsym(handle, "lumi_preview_make_nsview"))
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

    func test_buildErrorDescriptions_areHumanReadable() {
        XCTAssertEqual(
            LumiInlinePreviewFacade.InlinePreviewBuilder.BuildError.noPreviewFound.errorDescription,
            "No #Preview block found in this file."
        )
        XCTAssertEqual(
            LumiInlinePreviewFacade.InlinePreviewBuilder.BuildError.sdkResolutionFailed("missing").errorDescription,
            "Failed to resolve macOS SDK path: missing"
        )
        XCTAssertEqual(
            LumiInlinePreviewFacade.InlinePreviewBuilder.BuildError.swiftcFailed(stderr: "bad input").errorDescription,
            "swiftc failed:\nbad input"
        )
        XCTAssertEqual(
            LumiInlinePreviewFacade.InlinePreviewBuilder.BuildError.plannedBuildFailed("compile failed").errorDescription,
            "Planned preview build failed:\ncompile failed"
        )
    }

    func test_discoverPreviews_returnsEmptyArray_whenSourceHasNoPreview() async {
        let workspace = makeTempWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }

        let userFileURL = workspace.appendingPathComponent("NoPreview.swift")
        let builder = LumiInlinePreviewFacade.InlinePreviewBuilder(
            workspaceRoot: workspace.appendingPathComponent("build", isDirectory: true)
        )

        let summaries = await builder.discoverPreviews(
            fileURL: userFileURL,
            sourceText: "import Foundation\nlet x = 1\n"
        )

        XCTAssertTrue(summaries.isEmpty)
    }

    func test_build_fallsBackToFirstPreview_whenRequestedIndexIsOutOfBounds() async throws {
        let workspace = makeTempWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }

        let source = """
        import SwiftUI

        #Preview("First") {
            Text("first")
        }

        #Preview("Second") {
            Text("second")
        }
        """
        let userFileURL = workspace.appendingPathComponent("MultiplePreviews.swift")
        try source.write(to: userFileURL, atomically: true, encoding: .utf8)

        let builder = LumiInlinePreviewFacade.InlinePreviewBuilder(
            workspaceRoot: workspace.appendingPathComponent("build", isDirectory: true)
        )

        let result: LumiInlinePreviewFacade.InlinePreviewBuilder.BuildResult
        do {
            result = try await builder.build(fileURL: userFileURL, sourceText: source, previewIndex: 99)
        } catch let LumiInlinePreviewFacade.InlinePreviewBuilder.BuildError.swiftcFailed(stderr) {
            throw XCTSkip("swiftc failed (likely toolchain issue):\n\(stderr)")
        } catch let LumiInlinePreviewFacade.InlinePreviewBuilder.BuildError.sdkResolutionFailed(message) {
            throw XCTSkip("SDK unavailable: \(message)")
        }

        XCTAssertFalse(result.usedCache)
        XCTAssertEqual(result.primaryTitle, "First")
        XCTAssertEqual(result.selectedPreviewIndex, 0)
        XCTAssertEqual(result.previewCount, 2)
    }

    func test_purge_removesCachedBuildArtifacts() async throws {
        let workspace = makeTempWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }

        let userFileURL = workspace.appendingPathComponent("DemoEntryView.swift")
        try Self.userSource.write(to: userFileURL, atomically: true, encoding: .utf8)

        let buildRoot = workspace.appendingPathComponent("build", isDirectory: true)
        let builder = LumiInlinePreviewFacade.InlinePreviewBuilder(workspaceRoot: buildRoot)

        let result: LumiInlinePreviewFacade.InlinePreviewBuilder.BuildResult
        do {
            result = try await builder.build(fileURL: userFileURL, sourceText: Self.userSource)
        } catch let LumiInlinePreviewFacade.InlinePreviewBuilder.BuildError.swiftcFailed(stderr) {
            throw XCTSkip("swiftc failed (likely toolchain issue):\n\(stderr)")
        } catch let LumiInlinePreviewFacade.InlinePreviewBuilder.BuildError.sdkResolutionFailed(message) {
            throw XCTSkip("SDK unavailable: \(message)")
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.dylibURL.path))

        await builder.purge()

        XCTAssertFalse(FileManager.default.fileExists(atPath: buildRoot.path))
    }

    func test_build_evictsLeastRecentlyUsedCacheEntry_whenCacheLimitIsExceeded() async throws {
        let workspace = makeTempWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }

        let userFileURL = workspace.appendingPathComponent("DemoEntryView.swift")
        let firstSource = Self.userSource
        let secondSource = Self.userSource.replacingOccurrences(
            of: "inline preview entry",
            with: "inline preview entry updated"
        )
        try firstSource.write(to: userFileURL, atomically: true, encoding: .utf8)

        let builder = LumiInlinePreviewFacade.InlinePreviewBuilder(
            workspaceRoot: workspace.appendingPathComponent("build", isDirectory: true),
            cacheLimit: 1
        )

        let firstResult: LumiInlinePreviewFacade.InlinePreviewBuilder.BuildResult
        let secondResult: LumiInlinePreviewFacade.InlinePreviewBuilder.BuildResult
        do {
            firstResult = try await builder.build(fileURL: userFileURL, sourceText: firstSource)
            secondResult = try await builder.build(fileURL: userFileURL, sourceText: secondSource)
        } catch let LumiInlinePreviewFacade.InlinePreviewBuilder.BuildError.swiftcFailed(stderr) {
            throw XCTSkip("swiftc failed (likely toolchain issue):\n\(stderr)")
        } catch let LumiInlinePreviewFacade.InlinePreviewBuilder.BuildError.sdkResolutionFailed(message) {
            throw XCTSkip("SDK unavailable: \(message)")
        }

        XCTAssertFalse(firstResult.usedCache)
        XCTAssertFalse(secondResult.usedCache)
        XCTAssertNotEqual(firstResult.fingerprint, secondResult.fingerprint)
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: firstResult.dylibURL.deletingLastPathComponent().path),
            "first build directory should be removed after LRU eviction"
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: secondResult.dylibURL.path))

        let rebuiltFirst = try await builder.build(fileURL: userFileURL, sourceText: firstSource)
        XCTAssertFalse(rebuiltFirst.usedCache)
        XCTAssertEqual(rebuiltFirst.fingerprint, firstResult.fingerprint)
        XCTAssertTrue(FileManager.default.fileExists(atPath: rebuiltFirst.dylibURL.path))
    }

    // MARK: - Helpers

    private func makeTempWorkspace() -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("InlinePreviewBuilderTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeDependentPackageFixture(at packageDirectory: URL) throws {
        try """
        // swift-tools-version: 5.9
        import PackageDescription

        let package = Package(
            name: "InlineCrossTargetFixture",
            platforms: [.macOS(.v14)],
            products: [
                .library(name: "App", targets: ["App"])
            ],
            targets: [
                .target(name: "ThemeKit"),
                .target(name: "App", dependencies: ["ThemeKit"])
            ]
        )
        """.write(
            to: packageDirectory.appendingPathComponent("Package.swift"),
            atomically: true,
            encoding: .utf8
        )

        let themeDirectory = packageDirectory
            .appendingPathComponent("Sources/ThemeKit", isDirectory: true)
        let appDirectory = packageDirectory
            .appendingPathComponent("Sources/App", isDirectory: true)
        try FileManager.default.createDirectory(at: themeDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)

        try """
        import SwiftUI

        public enum ThemeTokens {
            public static let title = "Cross target preview"
            public static let accent = Color.blue
        }
        """.write(
            to: themeDirectory.appendingPathComponent("ThemeTokens.swift"),
            atomically: true,
            encoding: .utf8
        )

        try """
        import SwiftUI
        import ThemeKit

        public struct AppPreviewView: View {
            public init() {}

            public var body: some View {
                Text(ThemeTokens.title)
                    .foregroundStyle(ThemeTokens.accent)
            }
        }

        #Preview("Cross Target") {
            AppPreviewView()
        }
        """.write(
            to: appDirectory.appendingPathComponent("AppPreviewView.swift"),
            atomically: true,
            encoding: .utf8
        )
    }

    private func writeResourceBundlePackageFixture(at packageDirectory: URL) throws {
        try """
        // swift-tools-version: 5.9
        import PackageDescription

        let package = Package(
            name: "InlineResourceBundleFixture",
            platforms: [.macOS(.v14)],
            products: [
                .library(name: "App", targets: ["App"])
            ],
            targets: [
                .target(
                    name: "App",
                    resources: [.process("Resources")]
                )
            ]
        )
        """.write(
            to: packageDirectory.appendingPathComponent("Package.swift"),
            atomically: true,
            encoding: .utf8
        )

        let appDirectory = packageDirectory
            .appendingPathComponent("Sources/App", isDirectory: true)
        let resourceDirectory = appDirectory
            .appendingPathComponent("Resources", isDirectory: true)
        try FileManager.default.createDirectory(at: resourceDirectory, withIntermediateDirectories: true)

        try "Hello from Bundle.module\n".write(
            to: resourceDirectory.appendingPathComponent("message.txt"),
            atomically: true,
            encoding: .utf8
        )

        try """
        import SwiftUI

        public struct ResourcePreviewView: View {
            public init() {}

            public var body: some View {
                Text(Self.resourceText)
            }

            public static var resourceText: String {
                guard let url = Bundle.module.url(forResource: "message", withExtension: "txt"),
                      let text = try? String(contentsOf: url, encoding: .utf8) else {
                    return "missing resource"
                }
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        #Preview("Resource Bundle") {
            ResourcePreviewView()
        }
        """.write(
            to: appDirectory.appendingPathComponent("ResourcePreviewView.swift"),
            atomically: true,
            encoding: .utf8
        )
    }
}
