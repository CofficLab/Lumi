#if canImport(XCTest)
import XCTest
@testable import XcodeKit

final class IndexManifestTests: XCTestCase {
    func testManifestMatchesContextWhenFingerprintsEqual() {
        let inputs = IndexManifest.InputFingerprints(pbxprojHash: "sha256:abc")
        let toolchain = IndexManifest.ToolchainInfo(xcodeVersion: "16.4", xcodeBuildServerVersion: "1.1.0")
        let manifest = IndexManifest(
            workspacePath: "/tmp/Lumi.xcodeproj",
            scheme: "Lumi",
            configuration: "Debug",
            destination: "platform=macOS",
            inputs: inputs,
            toolchain: toolchain,
            compileDatabase: IndexManifest.CompileDatabaseInfo(entryCount: 10, includesSchemeModule: true)
        )

        XCTAssertTrue(
            manifest.matchesContext(
                scheme: "Lumi",
                configuration: "Debug",
                destination: "platform=macOS",
                inputs: inputs,
                toolchain: toolchain
            )
        )
    }

    func testManifestInvalidWhenPbxprojHashChanges() {
        let manifest = IndexManifest(
            workspacePath: "/tmp/Lumi.xcodeproj",
            scheme: "Lumi",
            configuration: "Debug",
            destination: "platform=macOS",
            inputs: IndexManifest.InputFingerprints(pbxprojHash: "sha256:old"),
            toolchain: IndexManifest.ToolchainInfo()
        )
        let newInputs = IndexManifest.InputFingerprints(pbxprojHash: "sha256:new")

        let reason = IndexManifestValidation.invalidationReason(
            manifest: manifest,
            compileDatabaseURL: URL(fileURLWithPath: "/tmp/.compile"),
            scheme: "Lumi",
            configuration: "Debug",
            destination: "platform=macOS",
            inputs: newInputs,
            toolchain: IndexManifest.ToolchainInfo()
        )
        XCTAssertEqual(reason, .compileDatabaseMissing)
    }

    func testSaveAndLoadManifestRoundTrip() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("IndexManifestTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let store = XcodeBuildServerStore(pluginDirectoryURL: temp)
        let workspace = "/tmp/Example.xcodeproj"
        let manifest = IndexManifest(
            workspacePath: workspace,
            scheme: "App",
            configuration: "Debug",
            destination: "platform=macOS",
            inputs: IndexManifest.InputFingerprints(pbxprojHash: "sha256:test"),
            toolchain: IndexManifest.ToolchainInfo(xcodeVersion: "16.0"),
            compileDatabase: IndexManifest.CompileDatabaseInfo(entryCount: 3, includesSchemeModule: true),
            builtAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        XCTAssertTrue(store.saveManifest(manifest, forWorkspace: workspace))
        let loaded = store.loadManifest(forWorkspace: workspace)
        XCTAssertEqual(loaded?.scheme, "App")
        XCTAssertEqual(loaded?.compileDatabase?.entryCount, 3)
    }
}
#endif
