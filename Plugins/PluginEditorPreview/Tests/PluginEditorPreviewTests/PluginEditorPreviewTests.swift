import Testing
import EditorService
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
