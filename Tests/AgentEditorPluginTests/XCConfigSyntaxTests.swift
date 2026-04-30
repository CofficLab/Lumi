#if canImport(XCTest)
import XCTest
@testable import Lumi

final class XCConfigSyntaxTests: XCTestCase {
    func testIncludeDirectiveMatchesQuotedPath() {
        let content = """
        #include "Configs/Base.xcconfig"
        SWIFT_VERSION = 5.10
        """

        let location = (content as NSString).range(of: "Configs/Base.xcconfig").location + 2
        let directive = XCConfigSyntax.includeDirective(at: location, in: content)

        XCTAssertEqual(directive?.path, "Configs/Base.xcconfig")
    }

    func testResolveIncludedFileURLUsesCurrentFileDirectory() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let configsDirectory = tempDirectory.appendingPathComponent("Configs", isDirectory: true)
        try FileManager.default.createDirectory(at: configsDirectory, withIntermediateDirectories: true)

        let currentFileURL = tempDirectory.appendingPathComponent("Debug.xcconfig")
        let includedURL = configsDirectory.appendingPathComponent("Base.xcconfig")
        FileManager.default.createFile(atPath: includedURL.path, contents: Data())

        let directive = try XCTUnwrap(
            XCConfigSyntax.IncludeDirective(
                path: "Configs/Base.xcconfig",
                pathRange: NSRange(location: 10, length: 21)
            )
        )

        let resolved = XCConfigSyntax.resolveIncludedFileURL(for: directive, currentFileURL: currentFileURL)
        XCTAssertEqual(resolved, includedURL.standardizedFileURL)
    }

    func testKeyOccurrencesExposeKeyAndLineNumbers() {
        let content = """
        PRODUCT_NAME = Lumi
        SWIFT_VERSION = 6.0
        """

        let occurrences = XCConfigSyntax.keyOccurrences(in: content)

        XCTAssertEqual(occurrences.map(\.key), ["PRODUCT_NAME", "SWIFT_VERSION"])
        XCTAssertEqual(occurrences.map(\.line), [1, 2])
    }
}
#endif
