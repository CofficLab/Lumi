import Testing
import Foundation
import ProviderEditor
import ProviderProject
@testable import QuickFileSearchPlugin

@MainActor
@Test func v2PluginPreservesQuickOpenIdentity() {
    let plugin = QuickFileSearchPlugin()
    #expect(plugin.id == "QuickFileSearch")
    #expect(plugin.metadata.policy == .alwaysOn)
}

// MARK: - Settings Project Status

/// 回归 #937：设置页曾把插件启动时的项目路径冻结为不可变字符串，
/// 之后切换或关闭项目仍显示旧项目（或一直 No project selected）。
@Test @MainActor func settingsStatusShowsProjectActiveAtStartup() {
    let provider = RecordingProjectProvider(currentProject: ProjectInfo(name: "A", path: "/tmp/A"))
    let status = QuickFileSearchSettingsStatus(project: provider)

    #expect(status.projectPath == "/tmp/A")
}

@Test @MainActor func settingsStatusFollowsProjectSwitch() {
    let provider = RecordingProjectProvider(currentProject: ProjectInfo(name: "A", path: "/tmp/A"))
    let status = QuickFileSearchSettingsStatus(project: provider)

    provider.switchProject(to: ProjectInfo(name: "B", path: "/tmp/B"))

    #expect(status.projectPath == "/tmp/B")
}

@Test @MainActor func settingsStatusRecoversAfterStartingWithoutProject() {
    let provider = RecordingProjectProvider(currentProject: nil)
    let status = QuickFileSearchSettingsStatus(project: provider)
    #expect(status.projectPath.isEmpty)

    provider.switchProject(to: ProjectInfo(name: "B", path: "/tmp/B"))

    #expect(status.projectPath == "/tmp/B")
}

@Test @MainActor func settingsStatusClearsPathAfterProjectClose() {
    let provider = RecordingProjectProvider(currentProject: ProjectInfo(name: "A", path: "/tmp/A"))
    let status = QuickFileSearchSettingsStatus(project: provider)

    provider.switchProject(to: nil)

    #expect(status.projectPath.isEmpty)
}

@Test @MainActor func settingsStatusIgnoresUnrelatedProjectEvents() {
    let provider = RecordingProjectProvider(currentProject: ProjectInfo(name: "A", path: "/tmp/A"))
    let status = QuickFileSearchSettingsStatus(project: provider)

    provider.emit(.openFilesChanged([URL(fileURLWithPath: "/tmp/A/File.swift")]))

    #expect(status.projectPath == "/tmp/A")
}

@MainActor
private final class RecordingProjectProvider: ProjectProviding {
    var currentProject: ProjectInfo?
    private var observers: [(ProjectProvidingEvent) -> Void] = []

    init(currentProject: ProjectInfo?) {
        self.currentProject = currentProject
    }

    var openFileURLs: [URL] { [] }
    var currentFileURL: URL? { nil }
    var projects: [ProjectInfo] { currentProject.map { [$0] } ?? [] }

    func switchProject(to project: ProjectInfo?) {
        currentProject = project
        emit(.currentProjectChanged(project, reason: .settingsChange))
    }

    func emit(_ event: ProjectProvidingEvent) {
        for observer in observers { observer(event) }
    }

    func openProject(at path: String, reason: ProjectChangeReason) async throws {}
    func updateCurrentFile(_ fileURL: URL?) {}
    func previewFile(_ fileURL: URL) {}
    func pinFile(_ fileURL: URL) {}
    func activateFile(_ fileURL: URL) {}
    func updateOpenFiles(_ fileURLs: [URL]) {}
    func closeFile(_ fileURL: URL) {}
    func closeProject(reason: ProjectChangeReason) async {}
    func refreshProjects() async throws {}
    func synchronizeProjects(_ projects: [ProjectInfo]) {}

    @discardableResult
    func addObserver(
        _ callback: @escaping (ProjectProvidingEvent) -> Void
    ) -> any ProjectProvidingObserverHandle {
        observers.append(callback)
        return RecordingProjectObserverHandle()
    }
}

@MainActor
private final class RecordingProjectObserverHandle: ProjectProvidingObserverHandle {
    func cancel() {}
}

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
    #expect(FileSearchService.shouldApplySearchResults(
        currentQuery: "  App  ", completedQuery: "App", currentGeneration: 3, completedGeneration: 3
    ))
    #expect(!FileSearchService.shouldApplySearchResults(
        currentQuery: "App", completedQuery: "AppS", currentGeneration: 3, completedGeneration: 3
    ))
}

@Test func staleSearchResultsFromPreviousProjectAreDiscarded() {
    #expect(!FileSearchService.shouldApplySearchResults(
        currentQuery: "App", completedQuery: "App", currentGeneration: 2, completedGeneration: 1
    ))
    #expect(FileSearchService.shouldApplySearchResults(
        currentQuery: "App", completedQuery: "App", currentGeneration: 2, completedGeneration: 2
    ))
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
    #expect(FileSearchService.shouldApplySearchResults(
        currentQuery: "App", completedQuery: " app ", currentGeneration: 0, completedGeneration: 0
    ))
    #expect(!FileSearchService.shouldApplySearchResults(
        currentQuery: "Application", completedQuery: "App", currentGeneration: 0, completedGeneration: 0
    ))
    #expect(!FileSearchService.shouldApplySearchResults(
        currentQuery: "", completedQuery: "App", currentGeneration: 0, completedGeneration: 0
    ))
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

// MARK: - Localization

/// 回归 #939：搜索面板的占位、索引中与无结果文案，en 条目曾被填成中文
/// 原文并标记 `translated`，英文界面因此显示简体中文；搜索框还直接使用
/// 中文字面量，绕过了插件 bundle 的本地化查找。
@Test func searchPanelStringsHaveEnglishTranslations() throws {
    let catalog = try loadQuickFileSearchCatalog()
    let expectedEnglish: [String: String] = [
        "搜索文件...": "Search files...",
        "正在索引文件...": "Indexing files...",
        "未找到匹配文件": "No matching files",
    ]

    for (key, englishValue) in expectedEnglish {
        let translations = try #require(catalog[key], "「\(key)」未进入本地化资源")
        #expect(
            translations["en"] == englishValue,
            "英文界面下「\(key)」显示 \(translations["en"] ?? "nil")，而不是英文"
        )
        #expect(translations["zh-Hans"] == key, "简体中文界面下「\(key)」保持中文")
    }
}

/// 从测试文件定位本包的 xcstrings（运行目录不可依赖）。
private func loadQuickFileSearchCatalog() throws -> [String: [String: String]] {
    let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let catalogURL = packageRoot
        .appendingPathComponent("Resources")
        .appendingPathComponent("Localizable.xcstrings")
    let data = try Data(contentsOf: catalogURL)
    let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let strings = try #require(root["strings"] as? [String: Any])

    var result: [String: [String: String]] = [:]
    for (key, value) in strings {
        let localizations = (value as? [String: Any])?["localizations"] as? [String: Any] ?? [:]
        var translations: [String: String] = [:]
        for (language, unit) in localizations {
            guard let unit = unit as? [String: Any],
                  let stringUnit = unit["stringUnit"] as? [String: Any],
                  let text = stringUnit["value"] as? String else { continue }
            translations[language] = text
        }
        result[key] = translations
    }
    return result
}
