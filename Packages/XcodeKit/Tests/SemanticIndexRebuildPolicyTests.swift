#if canImport(XCTest)
import XCTest
@testable import XcodeKit

final class SemanticIndexRebuildPolicyTests: XCTestCase {
    func testIncrementalMergeWhenPbxprojHashChanges() {
        // Project structure changed, but a database already exists to merge into → recompile only the
        // affected targets (incremental) and merge, instead of a costly clean full rebuild.
        let manifest = IndexManifest(
            workspacePath: "/tmp/App.xcodeproj",
            scheme: "App",
            configuration: "Debug",
            destination: "platform=macOS",
            inputs: IndexManifest.InputFingerprints(pbxprojHash: "sha256:old"),
            toolchain: IndexManifest.ToolchainInfo(),
            compileDatabase: IndexManifest.CompileDatabaseInfo(entryCount: 5, includesSchemeModule: true)
        )
        let strategy = SemanticIndexRebuildPolicy.strategy(
            manifest: manifest,
            inputs: IndexManifest.InputFingerprints(pbxprojHash: "sha256:new"),
            scheme: "App",
            configuration: "Debug",
            destination: "platform=macOS"
        )
        XCTAssertEqual(strategy, .incrementalBuildAndMerge)
    }

    func testIncrementalMergeWhenPackageResolvedHashChanges() {
        let manifest = IndexManifest(
            workspacePath: "/tmp/App.xcodeproj",
            scheme: "App",
            configuration: "Debug",
            destination: "platform=macOS",
            inputs: IndexManifest.InputFingerprints(
                pbxprojHash: "sha256:same",
                packageResolvedHash: "sha256:old-resolved"
            ),
            toolchain: IndexManifest.ToolchainInfo(),
            compileDatabase: IndexManifest.CompileDatabaseInfo(entryCount: 5, includesSchemeModule: true)
        )
        let strategy = SemanticIndexRebuildPolicy.strategy(
            manifest: manifest,
            inputs: IndexManifest.InputFingerprints(
                pbxprojHash: "sha256:same",
                packageResolvedHash: "sha256:new-resolved"
            ),
            scheme: "App",
            configuration: "Debug",
            destination: "platform=macOS"
        )
        XCTAssertEqual(strategy, .incrementalBuildAndMerge)
    }

    func testCleanBuildWhenManifestMissing() {
        // No manifest → nothing to merge into → the first build must be a full clean build that
        // produces a complete `.compile` from scratch.
        let strategy = SemanticIndexRebuildPolicy.strategy(
            manifest: nil,
            inputs: IndexManifest.InputFingerprints(pbxprojHash: "sha256:whatever"),
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
