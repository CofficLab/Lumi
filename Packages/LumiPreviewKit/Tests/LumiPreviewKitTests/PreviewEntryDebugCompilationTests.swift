import Foundation
import Testing
@testable import LumiPreviewKit

@Suite("PreviewEntryDebugCompilation")
struct PreviewEntryDebugCompilationTests {

    @Test("preview entry 编译参数包含 DEBUG，与 Xcode Debug 预览一致")
    func previewEntryDebugCompilerArgumentsIncludeDEBUG() {
        #expect(LumiPreviewFacade.PreviewEntryBuilder.previewDebugConditionArguments.contains("-DDEBUG"))
    }

    @Test("未定义 DEBUG 时，#if DEBUG 包裹的预览类型无法参与 preview entry 链接")
    func compileLibraryWithoutDebugDefineFailsForDebugGuardedType() async throws {
        let fixture = try makeDebugGuardedPreviewFixture()
        defer { try? FileManager.default.removeItem(at: fixture.packageDirectory) }

        try runSwiftBuild(packageDirectory: fixture.packageDirectory, targetName: fixture.targetName)

        let arguments = LumiPreviewFacade.SPMCompiler().previewCompilerArguments(
            packageDirectory: fixture.packageDirectory,
            targetName: fixture.targetName
        )
        #expect(!arguments.contains("-DDEBUG"))

        let dylibURL = fixture.packageDirectory.appendingPathComponent("PreviewEntry-without-debug.dylib")

        do {
            _ = try await LumiPreviewFacade.IncrementalCompiler().compileLibrary(
                sourceURLs: fixture.generatedSources,
                dylibURL: dylibURL,
                compilerArguments: arguments,
                moduleName: "PreviewEntryWithoutDebug"
            )
            Issue.record("Expected compilationFailed without -DDEBUG")
        } catch LumiPreviewFacade.PreviewError.compilationFailed(let message) {
            #expect(message.localizedCaseInsensitiveContains("DebugOnlyPreviewRoot"))
        } catch {
            Issue.record("Expected compilationFailed, got \(error)")
        }
    }

    @Test("SPM 分文件 #if DEBUG 预览通过 import 已构建模块链接，不重新编译整个 target")
    func buildEntryImportsPrebuiltModuleForSplitDebugGuardedPreview() async throws {
        let fixture = try makeSplitFileDebugGuardedPreviewFixture()
        defer { try? FileManager.default.removeItem(at: fixture.packageDirectory) }

        try runSwiftBuild(packageDirectory: fixture.packageDirectory, targetName: fixture.targetName)

        let sourceText = try String(contentsOf: fixture.previewSourceURL, encoding: .utf8)
        let discovery = try #require(
            LumiPreviewFacade.PreviewScanner()
                .scan(fileURL: fixture.previewSourceURL, sourceText: sourceText)
                .first
        )

        let entryURL = try await LumiPreviewFacade.PreviewEntryBuilder().buildEntry(
            for: discovery,
            configuration: .empty,
            buildStrategy: .spm(
                packageDirectory: fixture.packageDirectory,
                targetName: fixture.targetName
            )
        )

        let cacheDirectory = entryURL.deletingLastPathComponent()
        let targetSources = cacheDirectory.appendingPathComponent("TargetSources", isDirectory: true)
        #expect(!FileManager.default.fileExists(atPath: targetSources.path))

        guard let handle = dlopen(entryURL.path, RTLD_NOW | RTLD_LOCAL) else {
            let message = dlerror().map { String(cString: $0) } ?? "unknown dlopen error"
            Issue.record("Failed to open preview entry dylib: \(message)")
            return
        }
        defer { dlclose(handle) }

        #expect(dlsym(handle, LumiPreviewFacade.PreviewEntryBuilder.viewSymbolName) != nil)
    }

    @Test("SPM #if DEBUG 预览类型可通过 PreviewEntryBuilder 构建 entry dylib")
    func buildEntryCompilesDebugGuardedPreviewType() async throws {
        let fixture = try makeDebugGuardedPreviewFixture()
        defer { try? FileManager.default.removeItem(at: fixture.packageDirectory) }

        try runSwiftBuild(packageDirectory: fixture.packageDirectory, targetName: fixture.targetName)

        let sourceText = try String(contentsOf: fixture.previewSourceURL, encoding: .utf8)
        let discovery = try #require(
            LumiPreviewFacade.PreviewScanner()
                .scan(fileURL: fixture.previewSourceURL, sourceText: sourceText)
                .first
        )

        let entryURL = try await LumiPreviewFacade.PreviewEntryBuilder().buildEntry(
            for: discovery,
            configuration: .empty,
            buildStrategy: .spm(
                packageDirectory: fixture.packageDirectory,
                targetName: fixture.targetName
            )
        )

        guard let handle = dlopen(entryURL.path, RTLD_NOW | RTLD_LOCAL) else {
            let message = dlerror().map { String(cString: $0) } ?? "unknown dlopen error"
            Issue.record("Failed to open preview entry dylib: \(message)")
            return
        }
        defer { dlclose(handle) }

        #expect(dlsym(handle, LumiPreviewFacade.PreviewEntryBuilder.viewSymbolName) != nil)
    }

    private struct DebugGuardedPreviewFixture {
        let packageDirectory: URL
        let targetName: String
        let previewSourceURL: URL
        let generatedSources: [URL]
    }

    private struct SplitFileDebugGuardedPreviewFixture {
        let packageDirectory: URL
        let targetName: String
        let previewSourceURL: URL
    }

    private func makeSplitFileDebugGuardedPreviewFixture() throws -> SplitFileDebugGuardedPreviewFixture {
        let packageDirectory = try makeTemporaryDirectory()
        let targetName = "SplitDebugPreviewFixture"

        try """
        // swift-tools-version: 5.9
        import PackageDescription

        let package = Package(
            name: "SplitDebugPreviewFixturePackage",
            platforms: [.macOS(.v14)],
            products: [
                .library(name: "\(targetName)", targets: ["\(targetName)"])
            ],
            targets: [
                .target(name: "\(targetName)")
            ]
        )
        """.write(
            to: packageDirectory.appendingPathComponent("Package.swift"),
            atomically: true,
            encoding: .utf8
        )

        let sourceDirectory = packageDirectory
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent(targetName, isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)

        let previewSourceURL = sourceDirectory.appendingPathComponent("PreviewHost.swift")
        try """
        import SwiftUI

        #Preview("Split debug preview") {
            SplitDebugOnlyPreviewRoot()
        }
        """.write(to: previewSourceURL, atomically: true, encoding: .utf8)

        try """
        #if DEBUG
        import SwiftUI

        public struct SplitDebugOnlyPreviewRoot: View {
            public init() {}

            public var body: some View {
                Text("Split Debug Only")
            }
        }
        #endif
        """.write(
            to: sourceDirectory.appendingPathComponent("SplitDebugOnlyPreviewRoot.swift"),
            atomically: true,
            encoding: .utf8
        )

        return SplitFileDebugGuardedPreviewFixture(
            packageDirectory: packageDirectory,
            targetName: targetName,
            previewSourceURL: previewSourceURL
        )
    }

    private func makeDebugGuardedPreviewFixture() throws -> DebugGuardedPreviewFixture {
        let packageDirectory = try makeTemporaryDirectory()
        let targetName = "DebugPreviewFixture"

        try """
        // swift-tools-version: 5.9
        import PackageDescription

        let package = Package(
            name: "DebugPreviewFixturePackage",
            platforms: [.macOS(.v14)],
            products: [
                .library(name: "\(targetName)", targets: ["\(targetName)"])
            ],
            targets: [
                .target(name: "\(targetName)")
            ]
        )
        """.write(
            to: packageDirectory.appendingPathComponent("Package.swift"),
            atomically: true,
            encoding: .utf8
        )

        let sourceDirectory = packageDirectory
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent(targetName, isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)

        let previewSourceURL = sourceDirectory.appendingPathComponent("PreviewSource.swift")
        try """
        import SwiftUI

        #Preview("Debug guarded preview") {
            DebugOnlyPreviewRoot()
        }
        """.write(to: previewSourceURL, atomically: true, encoding: .utf8)

        try """
        #if DEBUG
        import SwiftUI

        public struct DebugOnlyPreviewRoot: View {
            public init() {}

            public var body: some View {
                Text("Debug Only")
            }
        }
        #endif
        """.write(
            to: sourceDirectory.appendingPathComponent("DebugOnlyPreviewRoot.swift"),
            atomically: true,
            encoding: .utf8
        )

        let generatedDirectory = packageDirectory.appendingPathComponent("GeneratedSources", isDirectory: true)
        try FileManager.default.createDirectory(at: generatedDirectory, withIntermediateDirectories: true)

        let debugOnlySourceURL = generatedDirectory.appendingPathComponent("DebugOnlyPreviewRoot.swift")
        try String(contentsOf: sourceDirectory.appendingPathComponent("DebugOnlyPreviewRoot.swift"), encoding: .utf8)
            .write(to: debugOnlySourceURL, atomically: true, encoding: .utf8)

        let previewEntryURL = generatedDirectory.appendingPathComponent("PreviewEntry.swift")
        try """
        import SwiftUI

        public func lumiPreviewMakeNSView() -> UnsafeMutableRawPointer? {
            let rootView = AnyView({
                DebugOnlyPreviewRoot()
            }())
            let view = NSHostingView(rootView: rootView)
            return Unmanaged.passRetained(view).toOpaque()
        }
        """.write(to: previewEntryURL, atomically: true, encoding: .utf8)

        return DebugGuardedPreviewFixture(
            packageDirectory: packageDirectory,
            targetName: targetName,
            previewSourceURL: previewSourceURL,
            generatedSources: [debugOnlySourceURL, previewEntryURL]
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewKitTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func runSwiftBuild(packageDirectory: URL, targetName: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["swift", "build", "--target", targetName]
        process.currentDirectoryURL = packageDirectory

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let output = String(
                data: outputPipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            ) ?? ""
            Issue.record("swift build failed: \(output)")
            return
        }
    }
}
