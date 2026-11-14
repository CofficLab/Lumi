import Foundation
import KitMarkdownCore
import Testing
@testable import KitMarkdown

/// 块缓存的流式性能契约。
///
/// 两条不变式：
/// 1. **解析不得持锁** —— 后台线程的全量/增量解析不能阻塞主线程的缓存查询，
///    否则流式输出期间每一次视图重建都会被后台解析卡住。
/// 2. **稳定前缀只解析一次** —— 流式追加推进稳定边界时，只解析新稳定的区段，
///    不得回头重解析整个前缀（否则长回复的累计成本是平方级）。
@MainActor
@Suite(.serialized)
struct MarkdownBlockCacheStreamingTests {

    @Test("后台解析不得阻塞主线程缓存查询")
    func backgroundParseDoesNotBlockCacheQueries() async throws {
        let cache = MarkdownBlockCache()
        // 足够大，保证全量解析耗时明显超过探测阈值（避免解析先于探针结束造成假绿）。
        let huge = String(repeating: "这是一段用于压测的中文段落内容。\n\n", count: 60_000)

        let parseTask = Task.detached(priority: .userInitiated) {
            cache.blocks(for: huge)
        }

        // 给后台任务时间拿到锁、进入解析。
        try await Task.sleep(for: .milliseconds(100))

        let start = ContinuousClock.now
        _ = cache.cachedBlocks(for: "查询探针")
        let elapsed = ContinuousClock.now - start

        await parseTask.value

        #expect(
            elapsed < .milliseconds(100),
            "主线程缓存查询被后台解析阻塞了 \(elapsed)（解析期间持锁）"
        )
    }

    @Test("流式追加每个字符至多稳定解析一次（线性成本）")
    func streamingAppendParseCostIsLinear() {
        let paragraphs = (0..<40).map {
            "第\($0)段：这是一段会持续增长的中文回复内容，用来模拟流式输出的稳定前缀。"
        }
        let full = paragraphs.joined(separator: "\n\n")

        // 逐步追加，复刻缓存推进稳定边界的过程，累计"新稳定区段"的解析字符数。
        var stableLength = 0
        var newlyStableTotal = 0
        var end = 1
        while end <= full.count {
            let markdown = String(full.prefix(end))
            let spans = MarkdownBlockCache.appendSpans(stableLength: stableLength, in: markdown)
            if let newlyStable = spans.newlyStable {
                newlyStableTotal += newlyStable.count
            }
            stableLength = spans.boundary
            end += 7
        }

        #expect(newlyStableTotal > 0, "流式过程中应当有前缀被稳定下来")
        #expect(
            newlyStableTotal <= full.count,
            "稳定前缀被重复解析：累计 \(newlyStableTotal) 字符 > 全文 \(full.count)（平方级成本）"
        )
    }

    @Test("流式追加经缓存得到的块序列与整体解析等价")
    func streamingAppendThroughCacheMatchesFullParse() {
        let cache = MarkdownBlockCache()
        let full = """
        # 标题

        第一段正文，包含**加粗**与`行内代码`。

        - 列表项 A
        - 列表项 B

        1. 有序一
        2. 有序二

        > 引用一段话。

        | 列 A | 列 B |
        | --- | --- |
        | 1 | 2 |

        最后一段。
        """

        var end = 1
        while end <= full.count {
            let markdown = String(full.prefix(end))
            let merged = cache.blocks(for: markdown)
            let expected = MarkdownParser.parse(markdown)
            #expect(
                blockTextContentsMatch(merged, expected),
                "end=\(end) 处增量结果与整体解析不一致"
            )
            end += 3
        }
    }

    @Test("代码块内的空行不得作为稳定边界（增量与整体解析结构等价，#340）")
    func streamingAppendKeepsCodeBlockWithInternalBlankLineIntact() {
        let cache = MarkdownBlockCache()
        // 复现 #340：代码块内部含空行，闭合围栏之后再追加普通段落。
        // 旧实现把代码块中途的空行当稳定边界，追加后代码块被拦腰拆断。
        let full = """
        ```swift
        let a = 1

        let b = 2
        ```

        After
        """

        var end = 1
        while end <= full.count {
            let markdown = String(full.prefix(end))
            let merged = cache.blocks(for: markdown)
            let expected = MarkdownParser.parse(markdown)
            #expect(
                merged == expected,
                "end=\(end) 处增量块结构与整体解析不一致：\n增量=\(merged)\n整体=\(expected)"
            )
            end += 1
        }
    }

    @Test("波浪号围栏内的空行同样不得作为稳定边界（#340）")
    func streamingAppendKeepsTildeFenceWithInternalBlankLineIntact() {
        let cache = MarkdownBlockCache()
        let full = """
        ~~~text
        first

        second
        ~~~

        Tail
        """

        var end = 1
        while end <= full.count {
            let markdown = String(full.prefix(end))
            let merged = cache.blocks(for: markdown)
            let expected = MarkdownParser.parse(markdown)
            #expect(
                merged == expected,
                "end=\(end) 处增量块结构与整体解析不一致：\n增量=\(merged)\n整体=\(expected)"
            )
            end += 1
        }
    }

    // MARK: - Helpers

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