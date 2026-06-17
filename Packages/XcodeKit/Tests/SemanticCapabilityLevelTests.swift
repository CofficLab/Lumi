#if canImport(XCTest)
import XCTest
@testable import XcodeKit

final class SemanticCapabilityLevelTests: XCTestCase {
    func testSyntaxOnlyForNonXcodeProject() {
        let level = SemanticCapabilityLevelResolver.resolve(
            isXcodeProject: false,
            buildServerAvailable: false,
            semanticIndexStatus: .notStarted,
            manifest: nil,
            compileDatabaseURL: nil,
            scheme: nil
        )
        XCTAssertEqual(level, .syntaxOnly)
    }

    func testFullIndexWhenReadyWithValidManifest() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("SemanticCapabilityLevelTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let compileURL = temp.appendingPathComponent(".compile")
        let entries: [[String: Any]] = [
            ["module_name": "Lumi", "command": "swiftc -module-name Lumi "]
        ]
        let data = try JSONSerialization.data(withJSONObject: entries)
        try data.write(to: compileURL)

        let manifest = IndexManifest(
            workspacePath: "/tmp/Lumi.xcodeproj",
            scheme: "Lumi",
            configuration: "Debug",
            destination: "platform=macOS",
            inputs: IndexManifest.InputFingerprints(),
            toolchain: IndexManifest.ToolchainInfo(),
            compileDatabase: IndexManifest.CompileDatabaseInfo(entryCount: 1, includesSchemeModule: true)
        )

        let level = SemanticCapabilityLevelResolver.resolve(
            isXcodeProject: true,
            buildServerAvailable: true,
            semanticIndexStatus: .ready,
            manifest: manifest,
            compileDatabaseURL: compileURL,
            scheme: "Lumi"
        )
        XCTAssertEqual(level, .fullIndex)
    }
}
#endif
