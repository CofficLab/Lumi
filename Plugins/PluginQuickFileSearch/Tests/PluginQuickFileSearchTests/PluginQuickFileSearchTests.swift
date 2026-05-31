import Testing
import Foundation
@testable import PluginQuickFileSearch

@Test func scanProjectFilesOnlyDropsRootPrefix() throws {
    let rootURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("QuickFileSearchTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: rootURL) }

    let nestedDirectory = rootURL
        .appendingPathComponent("nested", isDirectory: true)
        .appendingPathComponent(rootURL.path, isDirectory: true)
    try FileManager.default.createDirectory(at: nestedDirectory, withIntermediateDirectories: true)
    try "content".write(to: nestedDirectory.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)

    let results = FileSearchHelpers.scanProjectFiles(at: rootURL.path)
    let file = try #require(results.first { $0.name == "file.txt" })

    #expect(file.relativePath == "nested/\(String(rootURL.path.dropFirst()))/file.txt")
}

@Test func relativePathRejectsSiblingWithSharedPrefix() {
    let rootPath = "/tmp/project"
    let sibling = URL(fileURLWithPath: "/tmp/project-copy/file.txt")

    #expect(FileSearchHelpers.relativePath(for: sibling, rootPath: rootPath) == "file.txt")
}

@Test func scanProjectFilesSkipsRootBuildAndDependencyDirectories() throws {
    let rootURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("QuickFileSearchTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: rootURL) }

    let sourcesURL = rootURL.appendingPathComponent("Sources", isDirectory: true)
    let buildURL = rootURL.appendingPathComponent("build", isDirectory: true)
    let nodeModulesURL = rootURL.appendingPathComponent("node_modules", isDirectory: true)
    try FileManager.default.createDirectory(at: sourcesURL, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: buildURL, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: nodeModulesURL, withIntermediateDirectories: true)

    try "source".write(to: sourcesURL.appendingPathComponent("App.swift"), atomically: true, encoding: .utf8)
    try "generated".write(to: buildURL.appendingPathComponent("Generated.swift"), atomically: true, encoding: .utf8)
    try "dependency".write(to: nodeModulesURL.appendingPathComponent("index.js"), atomically: true, encoding: .utf8)

    let results = FileSearchHelpers.scanProjectFiles(at: rootURL.path)
    let relativePaths = Set(results.map(\.relativePath))

    #expect(relativePaths.contains("Sources/App.swift"))
    #expect(!relativePaths.contains("build/Generated.swift"))
    #expect(!relativePaths.contains("node_modules/index.js"))
}

@Test func shouldSkipPathMatchesDirectoryComponentAtPathEnd() {
    #expect(FileSearchHelpers.shouldSkipPath(URL(fileURLWithPath: "/tmp/project/build")))
    #expect(FileSearchHelpers.shouldSkipPath(URL(fileURLWithPath: "/tmp/project/node_modules")))
    #expect(!FileSearchHelpers.shouldSkipPath(URL(fileURLWithPath: "/tmp/project/building/App.swift")))
}

@Test func staleSearchResultsDoNotApplyToChangedQuery() {
    #expect(FileSearchService.shouldApplySearchResults(currentQuery: "App", completedQuery: " app "))
    #expect(!FileSearchService.shouldApplySearchResults(currentQuery: "Application", completedQuery: "App"))
    #expect(!FileSearchService.shouldApplySearchResults(currentQuery: "", completedQuery: "App"))
}

@Test func fuzzyMatchRejectsEmptyQuery() {
    #expect(!FileSearchHelpers.fuzzyMatch("Application.swift", query: ""))
}

@Test func fileSearchResultRowMapsCommonFileIconsWithoutDuplicateCases() {
    #expect(FileSearchResultRow.iconName(for: "App.swift") == "swift")
    #expect(FileSearchResultRow.iconName(for: "Bridge.h") == "doc.text")
    #expect(FileSearchResultRow.iconName(for: "View.mm") == "doc.text")
    #expect(FileSearchResultRow.iconName(for: "Archive.zip") == "archivebox")
}
