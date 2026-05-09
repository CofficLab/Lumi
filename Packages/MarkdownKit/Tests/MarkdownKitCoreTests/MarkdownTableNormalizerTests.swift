import Testing
@testable import MarkdownKitCore

struct MarkdownTableNormalizerTests {

    // MARK: - 规范表格（无变化）

    @Test
    func leavesWellFormedTableUnchanged() {
        let input = """
            | A | B |
            | --- | --- |
            | 1 | 2 |
            """
        let result = MarkdownTableNormalizer.normalize(input)
        // 解析后应为标准表格
        let blocks = MarkdownParser.parse(result)
        #expect(blocks.count == 1)
        #expect(blocks[0] == .table(headers: ["A", "B"], rows: [["1", "2"]]))
    }

    // MARK: - 缺失分隔线

    @Test
    func insertsMissingSeparatorLine() {
        let input = """
            | A | B |
            | 1 | 2 |
            """
        let result = MarkdownTableNormalizer.normalize(input)
        let blocks = MarkdownParser.parse(result)
        #expect(blocks.count == 1)
        #expect(blocks[0] == .table(headers: ["A", "B"], rows: [["1", "2"]]))
    }

    // MARK: - 单元格换行断裂

    @Test
    func mergesBrokenRowWithContinuation() {
        let input = """
            | A | B |
            | --- | --- |
            | cell1 |
            continuation |
            """
        let result = MarkdownTableNormalizer.normalize(input)
        let blocks = MarkdownParser.parse(result)
        #expect(blocks.count == 1)

        if case let .table(headers, rows) = blocks[0] {
            #expect(headers == ["A", "B"])
            // 续行被合并到上一行
            #expect(rows.count == 1)
            #expect(rows[0][0].contains("cell1"))
            #expect(rows[0][0].contains("continuation"))
        } else {
            Issue.record("Expected table block, got \(blocks[0])")
        }
    }

    // MARK: - 列数不一致

    @Test
    func padsShortRows() {
        let input = """
            | A | B | C |
            | --- | --- | --- |
            | 1 | 2 |
            """
        let result = MarkdownTableNormalizer.normalize(input)
        let blocks = MarkdownParser.parse(result)
        #expect(blocks.count == 1)

        if case let .table(_, rows) = blocks[0] {
            #expect(rows.count == 1)
            #expect(rows[0] == ["1", "2", ""])
        } else {
            Issue.record("Expected table block")
        }
    }

    // MARK: - 分隔线格式变体

    @Test
    func normalizesAlignSpecifiers() {
        let input = """
            | A | B |
            | :--- | ---: |
            | 1 | 2 |
            """
        let result = MarkdownTableNormalizer.normalize(input)
        let blocks = MarkdownParser.parse(result)
        #expect(blocks.count == 1)
        #expect(blocks[0] == .table(headers: ["A", "B"], rows: [["1", "2"]]))
    }

    // MARK: - 混合内容（表格前后有其他 Markdown）

    @Test
    func preservesNonTableContent() {
        let input = """
            # Title

            Some text here.

            | A | B |
            | --- | --- |
            | 1 | 2 |

            More text after table.
            """
        let result = MarkdownTableNormalizer.normalize(input)
        let blocks = MarkdownParser.parse(result)

        #expect(blocks.count == 4)
        #expect(blocks[0] == .heading(level: 1, text: "Title"))
        #expect(blocks[1] == .paragraph(text: "Some text here."))
        #expect(blocks[2] == .table(headers: ["A", "B"], rows: [["1", "2"]]))
        #expect(blocks[3] == .paragraph(text: "More text after table."))
    }

    // MARK: - 空内容

    @Test
    func handlesEmptyContent() {
        let result = MarkdownTableNormalizer.normalize("")
        #expect(result == "")
    }

    // MARK: - 无表格的普通文本

    @Test
    func preservesNonTableMarkdown() {
        let input = """
            # Hello

            - item 1
            - item 2

            ```swift
            let x = 1
            ```
            """
        let result = MarkdownTableNormalizer.normalize(input)
        let blocks = MarkdownParser.parse(result)

        #expect(blocks.count == 3)
        #expect(blocks[0] == .heading(level: 1, text: "Hello"))
        #expect(blocks[2] == .codeBlock(language: "swift", code: "let x = 1\n"))
    }
}
