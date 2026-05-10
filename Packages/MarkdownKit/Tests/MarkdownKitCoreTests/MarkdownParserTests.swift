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
    func preservesInlineMarkdownInListItems() {
        let blocks = MarkdownParser.parse(
            """
            - 普通项 **加粗** 和 `code`
            - 第二项 *斜体*
            """
        )

        #expect(
            blocks == [
                .unorderedList(
                    items: [
                        .init(text: "普通项 **加粗** 和 `code`"),
                        .init(text: "第二项 *斜体*"),
                    ]
                )
            ]
        )
    }

    @Test
    func preservesInlineMarkdownInQuotes() {
        let blocks = MarkdownParser.parse(
            """
            > 引用里包含 **加粗** 和 `code`
            """
        )

        #expect(blocks == [.quote(text: "引用里包含 **加粗** 和 `code`")])
    }

    @Test
    func parsesMixedChineseDocumentWithoutLosingInlineMarkdown() {
        let blocks = MarkdownParser.parse(
            """
            说明段落包含**“加粗标题”**。

            - 列表项保留 **加粗**

            ```swift
            let value = 1
            ```
            """
        )

        #expect(
            blocks == [
                .paragraph(text: "说明段落包含**“加粗标题”**。"),
                .unorderedList(items: [.init(text: "列表项保留 **加粗**")]),
                .codeBlock(language: "swift", code: "let value = 1\n"),
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

        // normalize 会自动补充分隔线，使表格能被正确解析
        #expect(
            blocks == [
                .table(
                    headers: ["Name", "Value"],
                    rows: [
                        ["nope", "nope"],
                        ["A", "1"],
                    ]
                )
            ]
        )
    }
}
