import Testing
@testable import MarkdownKitCore

struct MarkdownParserTests {

    @Test
    func parsesHeadingsParagraphsAndThematicBreaks() {
        let blocks = MarkdownParser.parse(
            """
            # Title

            Hello **world**

            ---
            """
        )

        #expect(
            blocks == [
                .heading(level: 1, text: "Title"),
                .paragraph(text: "Hello **world**"),
                .thematicBreak,
            ]
        )
    }

    @Test
    func parsesTaskListsAndOrderedLists() {
        let blocks = MarkdownParser.parse(
            """
            - [x] Done
            - [ ] Todo

            3. Third
            4. Fourth
            """
        )

        #expect(
            blocks == [
                .unorderedList(
                    items: [
                        .init(text: "Done", taskState: .done),
                        .init(text: "Todo", taskState: .todo),
                    ]
                ),
                .orderedList(
                    items: [
                        .init(index: 3, text: "Third"),
                        .init(index: 4, text: "Fourth"),
                    ]
                ),
            ]
        )
    }

    @Test
    func parsesCodeBlocksQuotesAndMermaidLanguage() {
        let blocks = MarkdownParser.parse(
            """
            > Quoted line

            ```mermaid
            graph TD; A-->B;
            ```
            """
        )

        #expect(
            blocks == [
                .quote(text: "Quoted line"),
                .codeBlock(language: "mermaid", code: "graph TD; A-->B;\n"),
            ]
        )
        #expect(MarkdownParser.isMermaidCodeBlock(language: "Mermaid"))
        #expect(!MarkdownParser.isMermaidCodeBlock(language: "swift"))
        #expect(!MarkdownParser.isMermaidCodeBlock(language: nil))
    }

    @Test
    func parsesPipeTablesAndPadsShortRows() {
        let blocks = MarkdownParser.parse(
            """
            | Name | Value |
            | ---- | ----- |
            | A    | 1     |
            | B    |
            """
        )

        #expect(
            blocks == [
                .table(
                    headers: ["Name", "Value"],
                    rows: [
                        ["A", "1"],
                        ["B", ""],
                    ]
                )
            ]
        )
    }

    @Test
    func fallsBackToParagraphWhenTableSeparatorIsInvalid() {
        let blocks = MarkdownParser.parse(
            """
            | Name | Value |
            | nope | nope |
            | A    | 1    |
            """
        )

        #expect(
            blocks == [
                .paragraph(text: "| Name | Value |\n| nope | nope |\n| A    | 1    |")
            ]
        )
    }
}
