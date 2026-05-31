import Testing
import Foundation
@testable import PluginEditorXcode

@Test func packageLoads() async throws {
    #expect(true)
}

@Test func schemeDeduplicationPreservesXcodebuildOrder() {
    let schemes = ["App", "Widget", "App", "Tests", "Widget", "Package"]

    let result = XcodeSchemeList.uniquePreservingOrder(schemes)

    #expect(result == ["App", "Widget", "Tests", "Package"])
}

@Test func quickOpenContributorReadsUTF16ProjectConfigFiles() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("PluginEditorXcodeTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let configURL = directory.appendingPathComponent("Debug.xcconfig")
    try """
    PRODUCT_NAME = Lumi
    OTHER_SWIFT_FLAGS = $(inherited)
    """.write(to: configURL, atomically: true, encoding: .utf16)

    let matches = XcodeProjectQuickOpenContributor.collectRawMatches(
        query: "product",
        projectRootPath: directory.path
    )

    #expect(matches.map(\.key) == ["PRODUCT_NAME"])
    #expect(matches.first?.relativePath == "Debug.xcconfig")
}
