import Testing
import EditorService
import Foundation
@testable import PluginEditorPreview

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

@Test func csvParserRejectsUnclosedQuotedFields() throws {
    #expect(throws: CSVPreviewParser.ParseError.unclosedQuote) {
        try CSVPreviewParser.parse("Name,Note\nAda,\"unfinished")
    }
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
