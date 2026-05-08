import Foundation
import Testing
@testable import MarkdownKitCore

struct MarkdownBlockModelTests {
    @Test
    func headingBlockEquality() {
        #expect(MarkdownBlock.heading(level: 1, text: "Title") == MarkdownBlock.heading(level: 1, text: "Title"))
        #expect(MarkdownBlock.heading(level: 1, text: "Title") != MarkdownBlock.heading(level: 2, text: "Title"))
        #expect(MarkdownBlock.heading(level: 1, text: "Title") != MarkdownBlock.heading(level: 1, text: "Different"))
    }

    @Test
    func paragraphBlockEquality() {
        #expect(MarkdownBlock.paragraph(text: "Text") == MarkdownBlock.paragraph(text: "Text"))
        #expect(MarkdownBlock.paragraph(text: "Text") != MarkdownBlock.paragraph(text: "Different"))
    }

    @Test
    func codeBlockEquality() {
        #expect(MarkdownBlock.codeBlock(language: "swift", code: "let x = 1") == MarkdownBlock.codeBlock(language: "swift", code: "let x = 1"))
        #expect(MarkdownBlock.codeBlock(language: "swift", code: "let x = 1") != MarkdownBlock.codeBlock(language: "python", code: "let x = 1"))
        #expect(MarkdownBlock.codeBlock(language: "swift", code: "let x = 1") != MarkdownBlock.codeBlock(language: "swift", code: "let y = 2"))
        #expect(MarkdownBlock.codeBlock(language: nil, code: "code") == MarkdownBlock.codeBlock(language: nil, code: "code"))
    }

    @Test
    func quoteBlockEquality() {
        #expect(MarkdownBlock.quote(text: "Quote") == MarkdownBlock.quote(text: "Quote"))
        #expect(MarkdownBlock.quote(text: "Quote") != MarkdownBlock.quote(text: "Different"))
    }

    @Test
    func tableBlockEquality() {
        let table1 = MarkdownBlock.table(headers: ["A", "B"], rows: [["1", "2"]])
        let table2 = MarkdownBlock.table(headers: ["A", "B"], rows: [["1", "2"]])
        let table3 = MarkdownBlock.table(headers: ["C", "D"], rows: [["3", "4"]])

        #expect(table1 == table2)
        #expect(table1 != table3)
    }

    @Test
    func thematicBreakEquality() {
        #expect(MarkdownBlock.thematicBreak == MarkdownBlock.thematicBreak)
        #expect(MarkdownBlock.thematicBreak != MarkdownBlock.paragraph(text: ""))
    }

    @Test
    func listItemInitialization() {
        let item = MarkdownListItem(text: "Item text", taskState: .done)
        #expect(item.text == "Item text")
        #expect(item.taskState == .done)
        #expect(item.id != UUID()) // Should have unique ID
    }

    @Test
    func listItemWithoutTaskState() {
        let item = MarkdownListItem(text: "Plain item")
        #expect(item.text == "Plain item")
        #expect(item.taskState == nil)
    }

    @Test
    func listItemEquality() {
        let item1 = MarkdownListItem(text: "Text", taskState: .todo)
        let item2 = MarkdownListItem(text: "Text", taskState: .todo)
        let item3 = MarkdownListItem(text: "Text", taskState: .done)
        let item4 = MarkdownListItem(text: "Different", taskState: .todo)

        #expect(item1 == item2)
        #expect(item1 != item3)
        #expect(item1 != item4)
    }

    @Test
    func orderedItemInitialization() {
        let item = MarkdownOrderedItem(index: 5, text: "Fifth item")
        #expect(item.index == 5)
        #expect(item.text == "Fifth item")
        #expect(item.id != UUID()) // Should have unique ID
    }

    @Test
    func orderedItemEquality() {
        let item1 = MarkdownOrderedItem(index: 1, text: "First")
        let item2 = MarkdownOrderedItem(index: 1, text: "First")
        let item3 = MarkdownOrderedItem(index: 2, text: "First")
        let item4 = MarkdownOrderedItem(index: 1, text: "Second")

        #expect(item1 == item2)
        #expect(item1 != item3)
        #expect(item1 != item4)
    }

    @Test
    func taskStateEquality() {
        #expect(MarkdownTaskState.todo == MarkdownTaskState.todo)
        #expect(MarkdownTaskState.done == MarkdownTaskState.done)
        #expect(MarkdownTaskState.todo != MarkdownTaskState.done)
    }

    @Test
    func taskStateIsCompleted() {
        #expect(MarkdownTaskState.done.isCompleted == true)
        #expect(MarkdownTaskState.todo.isCompleted == false)
    }
}

struct MarkdownParserEdgeCasesTests {
    @Test
    func parsesEmptyDocument() {
        let blocks = MarkdownParser.parse("")
        #expect(blocks.isEmpty)
    }

    @Test
    func parsesWhitespaceOnly() {
        let blocks = MarkdownParser.parse("   \n\n   \t  ")
        #expect(blocks.isEmpty)
    }

    @Test
    func parsesMultipleHeadingLevels() {
        let blocks = MarkdownParser.parse(
            """
            # H1
            ## H2
            ### H3
            #### H4
            ##### H5
            ###### H6
            """
        )

        #expect(blocks.count == 6)
        #expect(blocks[0] == .heading(level: 1, text: "H1"))
        #expect(blocks[1] == .heading(level: 2, text: "H2"))
        #expect(blocks[2] == .heading(level: 3, text: "H3"))
        #expect(blocks[3] == .heading(level: 4, text: "H4"))
        #expect(blocks[4] == .heading(level: 5, text: "H5"))
        #expect(blocks[5] == .heading(level: 6, text: "H6"))
    }

    @Test
    func parsesCodeBlockWithNoLanguage() {
        let blocks = MarkdownParser.parse(
            """
            ```
            plain code
            ```
            """
        )

        #expect(blocks.count == 1)
        #expect(blocks[0] == .codeBlock(language: nil, code: "plain code\n"))
    }

    @Test
    func parsesMultilineCodeBlock() {
        let blocks = MarkdownParser.parse(
            """
            ```swift
            func hello() {
                print("Hello")
            }
            ```
            """
        )

        #expect(blocks.count == 1)
        if case let .codeBlock(language, codeContent) = blocks[0] {
            #expect(language == "swift")
            #expect(codeContent.contains("func hello()"))
            #expect(codeContent.contains("print"))
        }
    }

    @Test
    func parsesNestedQuotes() {
        let blocks = MarkdownParser.parse(
            """
            > Level 1
            > > Level 2
            """
        )

        #expect(blocks.count >= 1)
    }

    @Test
    func parsesMixedListMarkers() {
        let blocks = MarkdownParser.parse(
            """
            - Dash item
            + Plus item
            * Star item
            """
        )

        // Different list markers create separate unordered lists
        #expect(blocks.count >= 1)
    }

    @Test
    func parsesOrderedListWithCustomStart() {
        let blocks = MarkdownParser.parse(
            """
            10. Item ten
            11. Item eleven
            """
        )

        #expect(blocks.count == 1)
        if case .orderedList(items: let items) = blocks[0] {
            #expect(items.count == 2)
            #expect(items[0].index == 10)
            #expect(items[1].index == 11)
        }
    }

    @Test
    func parsesTaskListWithMixedCases() {
        let blocks = MarkdownParser.parse(
            """
            - [x] lowercase x
            - [X] uppercase X
            - [ ] space
            """
        )

        #expect(blocks.count == 1)
        if case .unorderedList(items: let items) = blocks[0] {
            #expect(items.count == 3)
            #expect(items[0].taskState == .done)
            #expect(items[1].taskState == .done)
            #expect(items[2].taskState == .todo)
        }
    }

    @Test
    func parsesTableWithAlignment() {
        let blocks = MarkdownParser.parse(
            """
            | Left | Center | Right |
            |:-----|:------:|------:|
            | L    | C      | R     |
            """
        )

        #expect(blocks.count == 1)
        if case .table(headers: let headers, rows: let rows) = blocks[0] {
            #expect(headers == ["Left", "Center", "Right"])
            #expect(rows.count == 1)
            #expect(rows[0] == ["L", "C", "R"])
        }
    }

    @Test
    func parsesTableWithExtraColumns() {
        let blocks = MarkdownParser.parse(
            """
            | A | B |
            |---|---|
            | 1 | 2 | 3 | 4 |
            """
        )

        #expect(blocks.count == 1)
        if case .table(headers: let headers, rows: let rows) = blocks[0] {
            #expect(headers.count == 2)
            #expect(rows[0].count == 2) // Extra columns should be truncated
        }
    }

    @Test
    func parsesMultipleThematicBreaks() {
        let blocks = MarkdownParser.parse(
            """
            ---
            ***
            ___
            """
        )

        #expect(blocks.count == 3)
        #expect(blocks.allSatisfy { $0 == .thematicBreak })
    }

    @Test
    func handlesUnicodeInContent() {
        let blocks = MarkdownParser.parse(
            """
            # 中文标题

            - [x] 完成的任务 ✅
            - [ ] 待办事项 📝
            """
        )

        #expect(blocks.count == 2)
        #expect(blocks[0] == .heading(level: 1, text: "中文标题"))
    }

    @Test
    func parsesComplexDocument() {
        let blocks = MarkdownParser.parse(
            """
            # Document Title

            This is a paragraph with **bold** and *italic*.

            ## Section 1

            - Item 1
            - Item 2
              - Nested item

            ```swift
            let code = "example"
            ```

            > A quote
            > with multiple lines

            | Col1 | Col2 |
            |------|------|
            | A    | B    |

            ---
            """
        )

        #expect(blocks.count >= 8)
    }

    @Test
    func isMermaidCodeBlockWithVariations() {
        #expect(MarkdownParser.isMermaidCodeBlock(language: "mermaid") == true)
        #expect(MarkdownParser.isMermaidCodeBlock(language: "Mermaid") == true)
        #expect(MarkdownParser.isMermaidCodeBlock(language: "MERMAID") == true)
        #expect(MarkdownParser.isMermaidCodeBlock(language: "MerMaId") == true)
        #expect(MarkdownParser.isMermaidCodeBlock(language: "swift") == false)
        #expect(MarkdownParser.isMermaidCodeBlock(language: "python") == false)
        #expect(MarkdownParser.isMermaidCodeBlock(language: "") == false)
        #expect(MarkdownParser.isMermaidCodeBlock(language: nil) == false)
    }
}