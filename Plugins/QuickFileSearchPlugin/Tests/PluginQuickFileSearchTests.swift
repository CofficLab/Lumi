import Testing
import Foundation
import EditorService
@testable import QuickFileSearchPlugin

// MARK: - File Index

@Test func fileIndexStoreNeedsReindexWhenNeverUpdated() {
    let store = FileIndexStore(projectPath: "/tmp")
    #expect(store.needsReindex())
}

@Test func fileIndexStoreDoesNotNeedReindexAfterFreshUpdate() {
    var store = FileIndexStore(projectPath: "/tmp")
    store.update([FileResult(name: "A.swift", path: "/tmp/A.swift", relativePath: "A.swift", isDirectory: false, score: 0)])
    #expect(!store.needsReindex())
}

@Test func fileIndexStoreClearsAllState() {
    var store = FileIndexStore(projectPath: "/tmp")
    store.update([FileResult(name: "A.swift", path: "/tmp/A.swift", relativePath: "A.swift", isDirectory: false, score: 0)])
    store.clear()
    #expect(store.needsReindex())
}

// MARK: - FileIndex Expiry

@Test func fileIndexExpiresAfterFiveMinutes() {
    let stale = FileIndex(projectPath: "/tmp", files: [], lastUpdated: Date().addingTimeInterval(-301))
    #expect(stale.isExpired)

    let fresh = FileIndex(projectPath: "/tmp", files: [], lastUpdated: Date())
    #expect(!fresh.isExpired)
}

// MARK: - Fuzzy Match

@Test func fuzzyMatchIsCaseSensitiveSubsequenceCheck() {
    // fuzzyMatch 是区分大小写的子序列匹配
    #expect(FileSearchHelpers.fuzzyMatch("AppDelegate.swift", query: "AD"))
    #expect(FileSearchHelpers.fuzzyMatch("App.swift", query: "As"))
    #expect(!FileSearchHelpers.fuzzyMatch("AppDelegate.swift", query: "xyz"))
}

@Test func fuzzyMatchSingleCharAndFullMatch() {
    #expect(FileSearchHelpers.fuzzyMatch("App.swift", query: "A"))
    #expect(FileSearchHelpers.fuzzyMatch("App", query: "App"))
}

// MARK: - Search In Files

@Test func searchInFilesReturnsFilesSortedByScore() {
    let files = [
        FileResult(name: "Zebra.swift", path: "/p/Zebra.swift", relativePath: "Zebra.swift", isDirectory: false, score: 0),
        FileResult(name: "AppDelegate.swift", path: "/p/AppDelegate.swift", relativePath: "AppDelegate.swift", isDirectory: false, score: 0),
        FileResult(name: "App.swift", path: "/p/App.swift", relativePath: "App.swift", isDirectory: false, score: 0),
    ]
    // searchInFiles 内部对文件名做 lowercased 后与 query 比较
    // "a" 匹配所有三个文件：App.swift/AppDelegate 为前缀(100)，Zebra 为包含(80)
    let results = FileSearchHelpers.searchInFiles(files, query: "a")
    #expect(results.count == 3)
    // App.swift 和 AppDelegate.swift 均为前缀匹配 (score=100)，按名字字母序
    #expect(results.first?.name == "App.swift")
    #expect(results[1].name == "AppDelegate.swift")
    // Zebra 仅命中包含匹配
    #expect(results.last?.name == "Zebra.swift")
}

@Test func searchInFilesEmptyQueryReturnsEmpty() {
    let files = [
        FileResult(name: "App.swift", path: "/p/App.swift", relativePath: "App.swift", isDirectory: false, score: 0),
    ]
    #expect(FileSearchHelpers.searchInFiles(files, query: "").isEmpty)
    #expect(FileSearchHelpers.searchInFiles(files, query: "   ").isEmpty)
}

// MARK: - Icons

@Test func fileSearchResultRowMapsFileIconsByExtension() {
    // swift → swift
    #expect(FileSearchResultRow.iconName(for: "Package.swift") == "swift")
    // car → default
    #expect(FileSearchResultRow.iconName(for: "Assets.car") == "doc")
    // photo formats
    #expect(FileSearchResultRow.iconName(for: "photo.png") == "photo")
    #expect(FileSearchResultRow.iconName(for: "image.jpg") == "photo")
    #expect(FileSearchResultRow.iconName(for: "icon.svg") == "photo")
    // archive formats
    #expect(FileSearchResultRow.iconName(for: "archive.zip") == "archivebox")
    #expect(FileSearchResultRow.iconName(for: "backup.tar") == "archivebox")
    // config formats (注意 .env 无扩展名会走 default)
    #expect(FileSearchResultRow.iconName(for: ".env") == "doc")
    #expect(FileSearchResultRow.iconName(for: "app.conf") == "gearshape")
    // media formats
    #expect(FileSearchResultRow.iconName(for: "song.mp3") == "music.note")
    #expect(FileSearchResultRow.iconName(for: "clip.mp4") == "film")
}

@Test func fileSearchResultRowDefaultsUnknownExtensionsToDoc() {
    // unknown extensions → default "doc"
    #expect(FileSearchResultRow.iconName(for: "unknown.xyz") == "doc")
    #expect(FileSearchResultRow.iconName(for: "file.abc") == "doc")
}

@Test func fileSearchResultRowKnownNonCodeExtensionsReturnDocText() {
    // Known code/markup extensions return "doc.text"
    #expect(FileSearchResultRow.iconName(for: "README.md") == "doc.text")
    #expect(FileSearchResultRow.iconName(for: "style.css") == "doc.text")
    #expect(FileSearchResultRow.iconName(for: "data.json") == "doc.text")
    #expect(FileSearchResultRow.iconName(for: "page.html") == "doc.text")
}

// MARK: - Service

@Test @MainActor func quickOpenResultsWithEmptyQueryReturnsEmpty() {
    let service = FileSearchService.shared
    #expect(service.quickOpenResults(matching: "", projectPath: "/tmp", limit: 20).isEmpty)
    #expect(service.quickOpenResults(matching: "   ", projectPath: "/tmp", limit: 20).isEmpty)
}

@Test @MainActor func quickOpenResultsOnEmptyIndexReturnsEmpty() {
    let service = FileSearchService.shared
    service.clearIndex()
    #expect(service.quickOpenResults(matching: "App", projectPath: "/tmp/nonexistent-\(UUID())", limit: 20).isEmpty)
}

@Test func staleSearchResultsTrimmedQueriesAreEquivalent() {
    #expect(FileSearchService.shouldApplySearchResults(currentQuery: "  App  ", completedQuery: "App"))
    #expect(!FileSearchService.shouldApplySearchResults(currentQuery: "App", completedQuery: "AppS"))
}

// MARK: - Existing Tests

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

@Test func indexCompletionRefreshesOnlyActiveQueries() {
    #expect(FileSearchService.shouldRefreshSearchAfterIndexing(query: "App"))
    #expect(FileSearchService.shouldRefreshSearchAfterIndexing(query: " app "))
    #expect(!FileSearchService.shouldRefreshSearchAfterIndexing(query: " "))
}

@Test @MainActor func quickOpenResultsClampsNonPositiveLimits() {
    let service = FileSearchService.shared
    service.clearIndex()

    #expect(service.quickOpenResults(matching: "App", projectPath: "/tmp/project", limit: 0).isEmpty)
    #expect(service.quickOpenResults(matching: "App", projectPath: "/tmp/project", limit: -3).isEmpty)
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
