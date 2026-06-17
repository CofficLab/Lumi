#if canImport(XCTest)
import XCTest
@testable import XcodeKit

final class SemanticIndexRebuildPolicyTests: XCTestCase {
    func testCleanBuildWhenPbxprojHashChanges() {
        let manifest = IndexManifest(
            workspacePath: "/tmp/App.xcodeproj",
            scheme: "App",
            configuration: "Debug",
            destination: "platform=macOS",
            inputs: IndexManifest.InputFingerprints(pbxprojHash: "sha256:old"),
            toolchain: IndexManifest.ToolchainInfo()
        )
        let strategy = SemanticIndexRebuildPolicy.strategy(
            manifest: manifest,
            inputs: IndexManifest.InputFingerprints(pbxprojHash: "sha256:new"),
            scheme: "App",
            configuration: "Debug",
            destination: "platform=macOS"
        )
        XCTAssertEqual(strategy, .cleanBuildAndParse)
    }

    func testParseOnlyWhenOnlySchemeChanges() {
        let manifest = IndexManifest(
            workspacePath: "/tmp/App.xcodeproj",
            scheme: "OldScheme",
            configuration: "Debug",
            destination: "platform=macOS",
            inputs: IndexManifest.InputFingerprints(pbxprojHash: "sha256:same"),
            toolchain: IndexManifest.ToolchainInfo(),
            compileDatabase: IndexManifest.CompileDatabaseInfo(entryCount: 5, includesSchemeModule: true)
        )
        let strategy = SemanticIndexRebuildPolicy.strategy(
            manifest: manifest,
            inputs: IndexManifest.InputFingerprints(pbxprojHash: "sha256:same"),
            scheme: "NewScheme",
            configuration: "Debug",
            destination: "platform=macOS"
        )
        XCTAssertEqual(strategy, .parseFromDerivedDataOnly)
    }
}
#endif
