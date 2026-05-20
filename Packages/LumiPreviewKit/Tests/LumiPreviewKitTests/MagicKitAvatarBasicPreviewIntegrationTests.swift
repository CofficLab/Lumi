import Foundation
import Testing
@testable import LumiPreviewKit

/// End-to-end preview entry build against the real MagicKit package (sibling repo).
/// Skips when `LUMI_TEST_MAGICKIT_PATH` / default path is missing or `swift build` fails.
@Suite("MagicKitAvatarBasicPreviewIntegration")
struct MagicKitAvatarBasicPreviewIntegrationTests {

    @Test("preview link inputs include resource_bundle_accessor for MagicKit")
    func previewLinkInputsIncludeResourceBundleAccessor() throws {
        let packageDirectory = try #require(magicKitPackageDirectory())
        try runSwiftBuild(packageDirectory: packageDirectory, targetName: "MagicKit")

        let arguments = LumiPreviewFacade.SPMCompiler().previewCompilerArguments(
            packageDirectory: packageDirectory,
            targetName: "MagicKit"
        )
        let normalized = arguments.map { URL(fileURLWithPath: $0).standardizedFileURL.path }
        let includesAccessor = normalized.contains { path in
            path.hasSuffix("resource_bundle_accessor.swift.o")
        }
        #expect(includesAccessor)
    }

    @Test("MagicKit P+Basic AvatarBasicPreview builds linkable preview entry dylib")
    func magicKitAvatarBasicPreviewBuildsLinkableEntry() async throws {
        let packageDirectory = try #require(magicKitPackageDirectory())
        try runSwiftBuild(packageDirectory: packageDirectory, targetName: "MagicKit")

        let previewSourceURL = packageDirectory
            .appendingPathComponent("Sources/MagicKit/AvatarView/P+Basic.swift")
        #expect(FileManager.default.fileExists(atPath: previewSourceURL.path))

        let sourceText = try String(contentsOf: previewSourceURL, encoding: .utf8)
        let discovery = try #require(
            LumiPreviewFacade.PreviewScanner()
                .scan(fileURL: previewSourceURL, sourceText: sourceText)
                .first(where: { $0.title.contains("基础") || $0.bodySource?.contains("AvatarBasicPreview") == true })
                ?? LumiPreviewFacade.PreviewScanner()
                    .scan(fileURL: previewSourceURL, sourceText: sourceText)
                    .first
        )

        let entryURL = try await LumiPreviewFacade.PreviewEntryBuilder().buildEntry(
            for: discovery,
            configuration: .empty,
            buildStrategy: .spm(
                packageDirectory: packageDirectory,
                targetName: "MagicKit"
            )
        )

        #expect(FileManager.default.fileExists(atPath: entryURL.path))

        guard let handle = dlopen(entryURL.path, RTLD_NOW | RTLD_LOCAL) else {
            let message = dlerror().map { String(cString: $0) } ?? "unknown dlopen error"
            Issue.record("Failed to dlopen preview entry: \(message)")
            return
        }
        defer { dlclose(handle) }

        #expect(dlsym(handle, LumiPreviewFacade.PreviewEntryBuilder.viewSymbolName) != nil)
        #expect(dlsym(handle, LumiPreviewFacade.PreviewEntryBuilder.symbolName) != nil)
    }

    private func magicKitPackageDirectory() -> URL? {
        let envPath = ProcessInfo.processInfo.environment["LUMI_TEST_MAGICKIT_PATH"]
        var candidates: [URL] = []
        if let envPath, !envPath.isEmpty {
            candidates.append(URL(fileURLWithPath: envPath, isDirectory: true))
        }
        candidates.append(URL(fileURLWithPath: "/Users/angel/Code/Coffic/MagicKit", isDirectory: true))

        let testFile = URL(fileURLWithPath: #filePath)
        let lumiRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        candidates.append(
            lumiRoot
                .deletingLastPathComponent()
                .appendingPathComponent("MagicKit", isDirectory: true)
        )

        for candidate in candidates {
            let packageManifest = candidate.appendingPathComponent("Package.swift")
            if FileManager.default.fileExists(atPath: packageManifest.path) {
                return candidate
            }
        }
        return nil
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
            throw NSError(
                domain: "MagicKitAvatarBasicPreviewIntegrationTests",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "swift build failed: \(output)"]
            )
        }
    }
}
