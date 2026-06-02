import Testing
import EditorService
import Foundation
@testable import EditorPreviewPlugin

@Test func packageLoads() async throws {
    #expect(Bool(true))
}

@MainActor
@Test func previewViewModelStoreReusesViewModelForSameEditorService() {
    let store = EditorPreviewViewModelStore.shared
    store.resetForTesting()

    let editorService = EditorService(editorExtensionRegistry: EditorExtensionRegistry())
    let first = store.viewModel(for: editorService)
    let second = store.viewModel(for: editorService)

    #expect(first === second)
}

@MainActor
@Test func previewViewModelStoreSeparatesDifferentEditorServices() {
    let store = EditorPreviewViewModelStore.shared
    store.resetForTesting()

    let first = store.viewModel(for: EditorService(editorExtensionRegistry: EditorExtensionRegistry()))
    let second = store.viewModel(for: EditorService(editorExtensionRegistry: EditorExtensionRegistry()))

    #expect(first !== second)
}

@MainActor
@Test func previewViewModelDoesNotWarmUpWithoutPreviewFile() {
    let viewModel = EditorPreviewViewModel()

    viewModel.viewDidAppear(fileURL: nil, sourceText: nil)

    #expect(String(describing: viewModel.status) == "idle")
}

@MainActor
@Test func previewViewModelRestartsAfterStopOnlyWhenVisibleSwiftPreviewRemainsActive() {
    #expect(EditorPreviewViewModel.shouldRestartAfterStop(
        isViewVisible: true,
        previewMode: .swift,
        sourceText: "import SwiftUI\n#Preview { Text(\"Hi\") }"
    ))
    #expect(!EditorPreviewViewModel.shouldRestartAfterStop(
        isViewVisible: false,
        previewMode: .swift,
        sourceText: "import SwiftUI\n#Preview { Text(\"Hi\") }"
    ))
    #expect(!EditorPreviewViewModel.shouldRestartAfterStop(
        isViewVisible: true,
        previewMode: .csv(URL(fileURLWithPath: "/tmp/data.csv")),
        sourceText: "name,value"
    ))
    #expect(!EditorPreviewViewModel.shouldRestartAfterStop(
        isViewVisible: true,
        previewMode: .swift,
        sourceText: "import SwiftUI\nstruct ContentView: View {}"
    ))
}

@MainActor
@Test func previewViewModelKeepsSelectedPreviewWhenSameFileIsReapplied() {
    let viewModel = EditorPreviewViewModel()
    let fileURL = URL(fileURLWithPath: "/tmp/MultiplePreviews.swift")
    let source = """
    import SwiftUI

    #Preview("First") {
        Text("first")
    }

    #Preview("Second") {
        Text("second")
    }
    """

    viewModel.setActiveFile(fileURL, sourceText: source)
    viewModel.selectPreview(index: 1)
    viewModel.setActiveFile(fileURL, sourceText: source)

    #expect(viewModel.selectedPreviewIndex == 1)
}

@MainActor
@Test func previewViewModelRejectsUnavailablePreviewSelection() {
    #expect(EditorPreviewViewModel.shouldSelectPreview(
        index: 1,
        currentIndex: 0,
        availablePreviewIndexes: [0, 2],
        previewMode: .swift
    ) == false)
    #expect(EditorPreviewViewModel.shouldSelectPreview(
        index: -1,
        currentIndex: 0,
        availablePreviewIndexes: [0, 1],
        previewMode: .swift
    ) == false)
    #expect(EditorPreviewViewModel.shouldSelectPreview(
        index: 1,
        currentIndex: 0,
        availablePreviewIndexes: [0, 1],
        previewMode: .swift
    ))
    #expect(EditorPreviewViewModel.shouldSelectPreview(
        index: 1,
        currentIndex: 0,
        availablePreviewIndexes: [],
        previewMode: .swift
    ))
    #expect(EditorPreviewViewModel.shouldSelectPreview(
        index: 1,
        currentIndex: 0,
        availablePreviewIndexes: [0, 1],
        previewMode: .markdown(URL(fileURLWithPath: "/tmp/readme.md"))
    ) == false)
}

@Test func csvParserIgnoresQuotedDelimitersWhenDetectingSeparator() throws {
    let text = """
    "Company, legal name";Amount
    "ACME, Inc";42
    """

    let table = try CSVPreviewParser.parse(text)

    #expect(table.headers == ["Company, legal name", "Amount"])
    #expect(table.rows == [["ACME, Inc", "42"]])
}

@Test func csvParserDetectsTabsAndKeepsQuotedTabsInsideFields() throws {
    let text = """
    Name\tNote
    Ada\t"uses\ttabs"
    """

    let table = try CSVPreviewParser.parse(text)

    #expect(table.headers == ["Name", "Note"])
    #expect(table.rows == [["Ada", "uses\ttabs"]])
}

@Test func csvParserDetectsSeparatorAcrossMultilineQuotedHeader() throws {
    let text = """
    "Company
    legal name";Amount
    "ACME
    Inc";42
    """

    let table = try CSVPreviewParser.parse(text)

    #expect(table.headers == ["Company\nlegal name", "Amount"])
    #expect(table.rows == [["ACME\nInc", "42"]])
}

@Test func csvParserSupportsCarriageReturnLineEndings() throws {
    let table = try CSVPreviewParser.parse("Name,Score\rAda,42\rGrace,39")

    #expect(table.headers == ["Name", "Score"])
    #expect(table.rows == [["Ada", "42"], ["Grace", "39"]])
}

@Test func csvParserNormalizesRaggedRowsForStablePreviewColumns() throws {
    let table = try CSVPreviewParser.parse("Name,Score\nAda\nGrace,39,passed")

    #expect(table.headers == ["Name", "Score", "Column 3"])
    #expect(table.rows == [["Ada", "", ""], ["Grace", "39", "passed"]])
}

@Test func csvParserIgnoresUTF8ByteOrderMark() throws {
    let table = try CSVPreviewParser.parse("\u{FEFF}Name,Score\nAda,42")

    #expect(table.headers == ["Name", "Score"])
    #expect(table.rows == [["Ada", "42"]])
}

@Test func csvParserPreservesWhitespaceInsideQuotedFields() throws {
    let csv = "Name,Note\n"
        + "\"  Ada  \",\" keeps spaces \"\n"
        + "Grace, trims unquoted \n"
    let table = try CSVPreviewParser.parse(csv)

    #expect(table.rows == [
        ["  Ada  ", " keeps spaces "],
        ["Grace", "trims unquoted"],
    ])
}

@Test func csvParserRejectsUnclosedQuotedFields() throws {
    #expect(throws: CSVPreviewParser.ParseError.unclosedQuote) {
        try CSVPreviewParser.parse("Name,Note\nAda,\"unfinished")
    }
}

@Test func markdownTODOScannerHandlesCommonTaskListSyntax() {
    let stats = MarkdownTODOScanner.scan("""
    - [ ] Ship app
    - [X] Write release notes
    * [x] Update docs
    + [ ] Follow up
    """)

    #expect(stats == MarkdownTODOStats(total: 4, completed: 2))
}

@Test func markdownTODOScannerIgnoresFencedCodeBlocks() {
    let stats = MarkdownTODOScanner.scan("""
    - [x] Real task

    ```markdown
    - [ ] Example unchecked task
    - [x] Example checked task
    ```
    """)

    #expect(stats == MarkdownTODOStats(total: 1, completed: 1))
}

@Test func markdownTODOScannerHandlesOrderedTaskLists() {
    let stats = MarkdownTODOScanner.scan("""
    1. [x] Draft outline
    2. [ ] Fill details
    3) [X] Publish
    """)

    #expect(stats == MarkdownTODOStats(total: 3, completed: 2))
}

@Test func exportPolicyCopiesSVGImagesCaseInsensitively() {
    #expect(EditorPreviewExportPolicy.shouldCopyOriginalImage(for: URL(fileURLWithPath: "/tmp/icon.svg")))
    #expect(EditorPreviewExportPolicy.shouldCopyOriginalImage(for: URL(fileURLWithPath: "/tmp/ICON.SVG")))
    #expect(!EditorPreviewExportPolicy.shouldCopyOriginalImage(for: URL(fileURLWithPath: "/tmp/photo.png")))
}

@Test func exportPolicyBuildsUniqueDestinationWithoutForceUnwrappingDownloads() {
    let directoryURL = URL(fileURLWithPath: "/tmp/Downloads", isDirectory: true)
    let sourceURL = URL(fileURLWithPath: "/tmp/Icon.SVG")
    let existing = Set([
        directoryURL.appendingPathComponent("Icon.SVG"),
        directoryURL.appendingPathComponent("Icon (1).SVG"),
    ])

    let destinationURL = EditorPreviewExportPolicy.uniqueDestinationURL(
        for: sourceURL,
        in: directoryURL,
        fileExists: { existing.contains($0) }
    )

    #expect(destinationURL.lastPathComponent == "Icon (2).SVG")
}

@Test func exportPolicyBuildsUniqueScreenshotDestination() {
    let directoryURL = URL(fileURLWithPath: "/tmp/Downloads", isDirectory: true)
    let sourceURL = directoryURL.appendingPathComponent("Preview_2026-06-01_08-30-00.png")
    let existing = Set([
        directoryURL.appendingPathComponent("Preview_2026-06-01_08-30-00.png"),
        directoryURL.appendingPathComponent("Preview_2026-06-01_08-30-00 (1).png"),
    ])

    let destinationURL = EditorPreviewExportPolicy.uniqueDestinationURL(
        for: sourceURL,
        in: directoryURL,
        fileExists: { existing.contains($0) }
    )

    #expect(destinationURL.lastPathComponent == "Preview_2026-06-01_08-30-00 (2).png")
}

@Test func jsonPreviewParserKeepsValidJSONLLines() throws {
    let parsed = JSONPreviewParser.parse("""
    {"name":"Ada"}
    {"name":"Grace"}
    """)

    guard case let .success(value) = parsed,
          let rows = value as? [[String: String]] else {
        Issue.record("Expected JSONL rows to parse")
        return
    }

    #expect(rows == [["name": "Ada"], ["name": "Grace"]])
}

@Test func jsonPreviewParserRejectsPartiallyInvalidJSONL() {
    let parsed = JSONPreviewParser.parse("""
    {"name":"Ada"}
    {"name":
    {"name":"Grace"}
    """)

    guard case let .failure(error) = parsed,
          let parseError = error as? JSONParseError else {
        Issue.record("Expected JSONL parse failure")
        return
    }

    #expect(parseError == .invalidJSONLLine(2))
}

@Test func previewStorageFindsLegacyCacheRootsAcrossDBVersions() throws {
    let appSupport = FileManager.default.temporaryDirectory
        .appendingPathComponent("EditorPreviewStorageTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: appSupport) }

    let currentRoot = appSupport
        .appendingPathComponent("db_debug_v3", isDirectory: true)
        .appendingPathComponent("EditorPreviewPlugin", isDirectory: true)
    let previousRoot = appSupport
        .appendingPathComponent("db_debug_v2", isDirectory: true)
        .appendingPathComponent("EditorInlinePreviewPlugin", isDirectory: true)
    let unrelatedRoot = appSupport
        .appendingPathComponent("db_debug_v2", isDirectory: true)
        .appendingPathComponent("OtherPlugin", isDirectory: true)

    for directory in [currentRoot, previousRoot, unrelatedRoot] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    let roots = EditorPreviewStorage.cacheRootCandidates(currentRoot: currentRoot)
        .map(\.standardizedFileURL.path)

    #expect(roots.contains(currentRoot.standardizedFileURL.path))
    #expect(roots.contains(previousRoot.standardizedFileURL.path))
    #expect(!roots.contains(unrelatedRoot.standardizedFileURL.path))
}

@Test func stringCatalogSourceReadsUTF16CatalogFiles() throws {
    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("PreviewStringCatalog-\(UUID().uuidString).xcstrings")
    defer { try? FileManager.default.removeItem(at: fileURL) }

    try sampleStringCatalogWithStaleEntry.write(to: fileURL, atomically: true, encoding: .utf16)

    let source = try EditorPreviewViewModel.stringCatalogSource(from: fileURL)

    #expect(source.contains("\"Stale\""))
}

@MainActor
@Test func cleanCurrentStringCatalogReadsUTF16FilesWhenEditorTextIsUnavailable() throws {
    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("PreviewStringCatalogClean-\(UUID().uuidString).xcstrings")
    defer { try? FileManager.default.removeItem(at: fileURL) }

    try sampleStringCatalogWithStaleEntry.write(to: fileURL, atomically: true, encoding: .utf16)

    let editorService = EditorService(editorExtensionRegistry: EditorExtensionRegistry())
    let removedCount = try EditorPreviewViewModel().cleanCurrentStringCatalog(
        fileURL: fileURL,
        sourceText: nil,
        editorService: editorService
    )
    let cleanedSource = try String(contentsOf: fileURL, encoding: .utf8)

    #expect(removedCount == 1)
    #expect(!cleanedSource.contains("\"Stale\""))
    #expect(cleanedSource.contains("\"Active\""))
}

private let sampleStringCatalogWithStaleEntry = """
{
  "sourceLanguage": "en",
  "strings": {
    "Active": {
      "localizations": {
        "en": {
          "stringUnit": {
            "state": "translated",
            "value": "Active"
          }
        }
      }
    },
    "Stale": {
      "extractionState": "stale",
      "localizations": {
        "en": {
          "stringUnit": {
            "state": "translated",
            "value": "Stale"
          }
        }
      }
    }
  }
}
"""
