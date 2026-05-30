import Testing
@testable import PluginEditorPreview

@Test func packageLoads() async throws {
    #expect(Bool(true))
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
