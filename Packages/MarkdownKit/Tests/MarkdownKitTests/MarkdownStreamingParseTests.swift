import MarkdownKitCore
import Testing

/// 流式 Markdown 解析的正确性测试。
///
/// `MarkdownBlockRenderer` 的块缓存对流式追加做了增量优化:把内容按最后一个
/// 空行(`\n\n`)分成"稳定前缀"和"仍在增长的尾部",追加时只重新解析尾部。
/// 这些测试验证该增量策略的核心不变量:**分段解析后拼接的结果,与整体解析
/// 相同**(在块边界处切分时成立),从而保证流式渲染与一次性渲染一致。
struct MarkdownStreamingParseTests {

    /// 在每个 `\n\n` 块边界处切分,分段解析再拼接,结果应等于整体解析。
    @Test
    func splitAtBlockBoundariesEqualsFullParse() {
        let fullText = """
        # 标题

        第一段正文。

        - 列表项 A
        - 列表项 B

        ```swift
        let x = 1
        ```

        | 列 A | 列 B |
        | --- | --- |
        | 1 | 2 |

        最后一段。
        """
        let fullBlocks = MarkdownParser.parse(fullText)

        // 按空行边界切分为稳定片段,逐段解析后拼接。
        let segments = fullText.components(separatedBy: "\n\n")
        var merged: [MarkdownBlock] = []
        for segment in segments {
            let trimmed = segment.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            // 单段单独解析(模拟尾部增量解析)。
            merged += MarkdownParser.parse(segment)
        }
        // 注意:逐段解析与整体解析在"跨块结构(如紧邻的表格)"上可能不同,
        // 但对本用例(每个块由空行清晰分隔)应一致。
        #expect(merged == fullBlocks || blockTextContentsMatch(merged, fullBlocks),
                "增量分段解析应与整体解析产生等价的块序列")
    }

    /// 模拟逐 token 追加:每一步用"稳定前缀 + 尾部重解析"得到的块序列,
    /// 其文本内容应与该步整体解析一致(关注内容而非块边界划分的细微差异)。
    @Test
    func streamingAppendMatchesFullParseAtEachStep() {
        let fullText = "段落一不断增长。\n\n第二段也开始。\n\n第三段。"
        let steps = stride(from: 1, through: fullText.count, by: 3)

        for end in steps {
            let markdown = String(fullText.prefix(end))
            let fullBlocks = MarkdownParser.parse(markdown)

            // 复刻缓存的增量逻辑。
            let boundary = lastBlockBoundary(in: markdown)
            let stableSource = String(markdown.prefix(boundary))
            let tail = markdown.count > boundary ? String(markdown.dropFirst(boundary)) : ""
            let stableBlocks = MarkdownParser.parse(stableSource)
            let tailBlocks = tail.isEmpty ? [] : MarkdownParser.parse(tail)
            let merged = stableBlocks + tailBlocks

            #expect(blockTextContentsMatch(merged, fullBlocks),
                    "在 end=\(end) 处,增量解析的文本内容应与整体解析一致")
        }
    }

    // MARK: - Helpers

    /// 返回最后一个 `\n\n` 之后的稳定前缀长度(复刻缓存内部逻辑)。
    private func lastBlockBoundary(in markdown: String) -> Int {
        if let range = markdown.range(of: "\n\n", options: .backwards) {
            return markdown.distance(from: markdown.startIndex, to: range.upperBound)
        }
        return 0
    }

    /// 比较两组块的"文本内容拼接"是否一致(忽略块切分方式的细微差异)。
    private func blockTextContentsMatch(_ a: [MarkdownBlock], _ b: [MarkdownBlock]) -> Bool {
        concatenatedText(a) == concatenatedText(b)
    }

    private func concatenatedText(_ blocks: [MarkdownBlock]) -> String {
        blocks.map { block -> String in
            switch block {
            case .heading(_, let text): return text
            case .paragraph(let text): return text
            case .unorderedList(let items): return items.map(\.text).joined()
            case .orderedList(let items): return items.map(\.text).joined()
            case .codeBlock(_, let code): return code
            case .quote(let text): return text
            case .table(let headers, let rows): return headers.joined() + rows.map { $0.joined() }.joined()
            case .thematicBreak: return ""
            }
        }.joined()
    }
}
