#if canImport(XCTest)
import XCTest
@testable import XcodeKit

final class CompileDatabaseValidatorTests: XCTestCase {
    func testMetadataOnlyRejectsMissingFile() {
        let manifest = IndexManifest(
            workspacePath: "/tmp/App.xcodeproj",
            scheme: "App",
            configuration: "Debug",
            destination: "platform=macOS",
            inputs: IndexManifest.InputFingerprints(),
            toolchain: IndexManifest.ToolchainInfo(),
            compileDatabase: IndexManifest.CompileDatabaseInfo(entryCount: 1, includesSchemeModule: true)
        )
        let result = CompileDatabaseValidator.validateMetadataOnly(
            manifest: manifest,
            compileDatabaseURL: URL(fileURLWithPath: "/tmp/missing.compile"),
            scheme: "App",
            configuration: "Debug",
            destination: "platform=macOS",
            inputs: IndexManifest.InputFingerprints(),
            toolchain: IndexManifest.ToolchainInfo()
        )
        XCTAssertFalse(result.isValid)
    }

    func testMetadataOnlyRejectsFileSizeMismatch() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("CompileDatabaseValidatorTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let compileURL = temp.appendingPathComponent(".compile")
        try Data("{}".utf8).write(to: compileURL)
        let manifest = IndexManifest(
            workspacePath: "/tmp/App.xcodeproj",
            scheme: "App",
            configuration: "Debug",
            destination: "platform=macOS",
            inputs: IndexManifest.InputFingerprints(),
            toolchain: IndexManifest.ToolchainInfo(),
            compileDatabase: IndexManifest.CompileDatabaseInfo(
                entryCount: 1,
                includesSchemeModule: true,
                fileSizeBytes: 999
            )
        )
        let result = CompileDatabaseValidator.validateMetadataOnly(
            manifest: manifest,
            compileDatabaseURL: compileURL,
            scheme: "App",
            configuration: "Debug",
            destination: "platform=macOS",
            inputs: IndexManifest.InputFingerprints(),
            toolchain: IndexManifest.ToolchainInfo()
        )
        XCTAssertFalse(result.isValid)
    }

    func testContentHashDetectsMutation() async throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("CompileDatabaseValidatorTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let compileURL = temp.appendingPathComponent(".compile")
        try Data("[]".utf8).write(to: compileURL)
        let hash = IndexManifest.compileDatabaseContentHash(at: compileURL)!
        try Data("[{\"module_name\":\"App\"}]".utf8).write(to: compileURL)

        let manifest = IndexManifest(
            workspacePath: "/tmp/App.xcodeproj",
            scheme: "App",
            configuration: "Debug",
            destination: "platform=macOS",
            inputs: IndexManifest.InputFingerprints(),
            toolchain: IndexManifest.ToolchainInfo(),
            compileDatabase: IndexManifest.CompileDatabaseInfo(
                entryCount: 1,
                includesSchemeModule: true,
                contentHash: hash
            )
        )
        let result = await CompileDatabaseValidator.validateContentHash(
            manifest: manifest,
            compileDatabaseURL: compileURL
        )
        XCTAssertFalse(result.isValid)
    }
}
#endif
